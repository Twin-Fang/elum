package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.infrastructure.client.SupertonicTtsClient;
import com.chuseok22.elumserver.common.infrastructure.properties.TtsProperties;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineStepSpeechStorage;
import jakarta.annotation.PreDestroy;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.RejectedExecutionException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * 단계 음성 대기열: 커밋 후 예약, 중복 제거, 한 번에 1건 (#675)
 * AI 서버가 요청을 하나씩 처리 (실측 동시 20건 > 최대 25.7초) > 동시에 보내면 대기만 쌓임
 */
@Slf4j
@Component
public class RoutineStepSpeechQueue {

  private final RoutineStepSpeechFiller routineStepSpeechFiller;
  private final RoutineStepSpeechStorage routineStepSpeechStorage;
  private final TtsProperties ttsProperties;
  private final SupertonicTtsClient supertonicTtsClient;
  private final ExecutorService executor;

  /// 실패한 단계를 주기 작업이 다시 넣기까지 쉬는 시간 (같은 실패 단계가 매번 자리를 차지하지 않게)
  private static final Duration FAILURE_COOLDOWN = Duration.ofMinutes(30);

  private final Clock clock;

  /// 대기 중(아직 시작 안 함) stepId — 시작할 때 최신 글을 읽으므로 또 넣어도 한 번만
  private final Set<String> queuedStepIds = ConcurrentHashMap.newKeySet();

  /// 처리 중 stepId. 처리 중에 다시 넣으면 끝난 뒤 한 번 더 (합성 중 글 수정 > 새 글 음성)
  private final Set<String> runningStepIds = ConcurrentHashMap.newKeySet();

  /// 처리 중에 다시 요청된 stepId
  private final Set<String> dirtyStepIds = ConcurrentHashMap.newKeySet();

  /// 최근 합성 실패 시각 by stepId (재시작 시 비움)
  private final Map<String, Instant> lastFailureAtByStepId = new ConcurrentHashMap<>();

  @Autowired
  public RoutineStepSpeechQueue(
    RoutineStepSpeechFiller routineStepSpeechFiller, RoutineStepSpeechStorage routineStepSpeechStorage,
    TtsProperties ttsProperties, SupertonicTtsClient supertonicTtsClient
  ) {
    this(routineStepSpeechFiller, routineStepSpeechStorage, ttsProperties, supertonicTtsClient,
      Executors.newSingleThreadExecutor(Thread.ofPlatform().name("routine-speech").daemon(true).factory()),
      Clock.systemUTC());
  }

  RoutineStepSpeechQueue(
    RoutineStepSpeechFiller routineStepSpeechFiller, RoutineStepSpeechStorage routineStepSpeechStorage,
    TtsProperties ttsProperties, SupertonicTtsClient supertonicTtsClient, ExecutorService executor, Clock clock
  ) {
    this.clock = clock;
    this.routineStepSpeechFiller = routineStepSpeechFiller;
    this.routineStepSpeechStorage = routineStepSpeechStorage;
    this.ttsProperties = ttsProperties;
    this.supertonicTtsClient = supertonicTtsClient;
    this.executor = executor;
  }

  /**
   * 사용 조건 2개: 설정 켜짐, AI 서버 키 있음
   */
  public boolean isEnabled() {
    return ttsProperties.isEnabled() && supertonicTtsClient.isAvailable();
  }

  /**
   * 지금 트랜잭션 커밋 후 넣기 (롤백되면 넣지 않음). 트랜잭션 밖이면 바로 넣기
   */
  public void enqueueAfterCommit(Collection<String> stepIds) {
    if (!isEnabled() || stepIds.isEmpty()) {
      return;
    }
    runAfterCommit(() -> stepIds.forEach(this::enqueue));
  }

  /**
   * 단계 1개 커밋 후 넣기 (id 가 없으면 무시)
   */
  public void enqueueAfterCommit(String stepId) {
    if (stepId != null) {
      enqueueAfterCommit(List.of(stepId));
    }
  }

  /**
   * 커밋 후 단계 음성 폴더 삭제 (단계·일과 삭제 시)
   */
  public void deleteStepsAfterCommit(Collection<String> stepIds) {
    if (stepIds.isEmpty()) {
      return;
    }
    runAfterCommit(() -> stepIds.forEach(routineStepSpeechStorage::deleteStep));
  }

  /**
   * 커밋 후 옛 음성 파일 1개 삭제 (글 수정 시)
   */
  public void deleteSpeechAfterCommit(String speechKey) {
    if (speechKey == null || speechKey.isBlank()) {
      return;
    }
    runAfterCommit(() -> routineStepSpeechStorage.delete(speechKey));
  }

  private static void runAfterCommit(Runnable action) {
    if (!TransactionSynchronizationManager.isSynchronizationActive()) {
      action.run();
      return;
    }
    TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
      @Override
      public void afterCommit() {
        action.run();
      }
    });
  }

  /**
   * 대기열에 넣기. 대기 중이면 무시, 처리 중이면 끝난 뒤 한 번 더
   */
  public synchronized void enqueue(String stepId) {
    if (stepId == null || !isEnabled() || queuedStepIds.contains(stepId)) {
      return;
    }
    if (runningStepIds.contains(stepId)) {
      dirtyStepIds.add(stepId);
      return;
    }
    queuedStepIds.add(stepId);
    try {
      executor.execute(() -> run(stepId));
    } catch (RejectedExecutionException e) {
      queuedStepIds.remove(stepId);
      log.warn("[routine speech] rejected enqueue : stepId={}", stepId);
    }
  }

  private void run(String stepId) {
    synchronized (this) {
      queuedStepIds.remove(stepId);
      runningStepIds.add(stepId);
    }
    try {
      if (routineStepSpeechFiller.fill(stepId)) {
        lastFailureAtByStepId.remove(stepId);
      } else {
        lastFailureAtByStepId.put(stepId, clock.instant());
      }
    } finally {
      // 처리 끝 (성공·실패 공통). 처리 중 다시 요청됐으면 한 번 더
      boolean isRequestedAgain;
      synchronized (this) {
        runningStepIds.remove(stepId);
        isRequestedAgain = dirtyStepIds.remove(stepId);
      }
      if (isRequestedAgain) {
        enqueue(stepId);
      }
    }
  }

  /**
   * 주기 작업용: 최근 실패해 쉬는 중인 단계인지
   */
  public boolean isCoolingDown(String stepId) {
    Instant failedAt = lastFailureAtByStepId.get(stepId);
    return failedAt != null && failedAt.plus(FAILURE_COOLDOWN).isAfter(clock.instant());
  }

  /// 대기·처리 중인 건수 (주기 작업이 적체를 보고 건너뜀)
  public int pendingCount() {
    return queuedStepIds.size() + runningStepIds.size();
  }

  @PreDestroy
  void shutdown() {
    executor.shutdownNow();
  }
}
