package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.infrastructure.client.SupertonicTtsClient;
import com.chuseok22.elumserver.common.infrastructure.properties.TtsProperties;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.service.RoutineQueryService.StepSpeech;
import com.chuseok22.elumserver.routine.application.service.RoutineStepSpeechFiller.FilledSpeech;
import jakarta.annotation.PreDestroy;
import java.time.Duration;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/**
 * 단계 음성 제공 (#765): 저장본 조회 > 없으면 요청 중 즉석 합성 > 그래도 없으면 빈 값 (앱은 다음 엔진으로)
 * 즉석 합성 조건 3개: 한국어 일과·읽을 문장 있음 (Filler 판단), 단계당 1회 (진행 중 공유), 동시 합성 수 상한
 * 트랜잭션 밖에서 동작 (합성 중 DB 연결을 잡지 않고, 열쇠 갱신 UPDATE 가 읽기 전용에 막히지 않게)
 */
@Slf4j
@Service
public class RoutineStepSpeechProvider {

  // 동시 합성 상한 (AI 서버가 하나씩 처리 > 더 보내면 대기만 쌓여 앱 대기 8초를 넘김)
  static final int MAX_CONCURRENT_SYNTHESES = 2;
  // 요청이 합성을 기다리는 상한: 합성 읽기 제한 6초 + 저장 여유 1초 (앱 받기 대기 상한 8초 미만)
  static final Duration MAX_WAIT = SupertonicTtsClient.ON_DEMAND_READ_TIMEOUT.plusSeconds(1);

  private final RoutineQueryService routineQueryService;
  private final RoutineStepSpeechFiller routineStepSpeechFiller;
  private final TtsProperties ttsProperties;
  private final SupertonicTtsClient supertonicTtsClient;
  private final ExecutorService executor;
  private final Semaphore synthesisPermits;
  private final Duration maxWait;

  /// 진행 중인 즉석 합성 by stepId (같은 단계 동시 요청은 이 결과를 함께 기다림)
  private final Map<String, CompletableFuture<Optional<FilledSpeech>>> inFlightByStepId = new ConcurrentHashMap<>();

  @Autowired
  public RoutineStepSpeechProvider(
    RoutineQueryService routineQueryService, RoutineStepSpeechFiller routineStepSpeechFiller,
    TtsProperties ttsProperties, SupertonicTtsClient supertonicTtsClient
  ) {
    this(routineQueryService, routineStepSpeechFiller, ttsProperties, supertonicTtsClient,
      Executors.newFixedThreadPool(MAX_CONCURRENT_SYNTHESES,
        Thread.ofPlatform().name("routine-speech-on-demand-", 0).daemon(true).factory()),
      MAX_CONCURRENT_SYNTHESES, MAX_WAIT);
  }

  RoutineStepSpeechProvider(
    RoutineQueryService routineQueryService, RoutineStepSpeechFiller routineStepSpeechFiller,
    TtsProperties ttsProperties, SupertonicTtsClient supertonicTtsClient,
    ExecutorService executor, int maxConcurrentSyntheses, Duration maxWait
  ) {
    this.routineQueryService = routineQueryService;
    this.routineStepSpeechFiller = routineStepSpeechFiller;
    this.ttsProperties = ttsProperties;
    this.supertonicTtsClient = supertonicTtsClient;
    this.executor = executor;
    this.synthesisPermits = new Semaphore(maxConcurrentSyntheses);
    this.maxWait = maxWait;
  }

  /**
   * 권한 확인 > 저장본 > 없으면 즉석 합성. 못 만들면 빈 값 (권한 없음·없는 단계는 기존 예외 그대로)
   */
  public Optional<StepSpeech> getStepSpeech(Caller caller, String routineId, String stepId) {
    Optional<StepSpeech> storedSpeech = routineQueryService.getStepSpeech(caller, routineId, stepId);
    if (storedSpeech.isPresent() || !isOnDemandEnabled()) {
      return storedSpeech;
    }
    return synthesizeOnce(stepId).map(filled -> new StepSpeech(filled.speechKey(), filled.wav()));
  }

  /// 사용 조건 2개: 설정 켜짐, AI 서버 키 있음
  private boolean isOnDemandEnabled() {
    return ttsProperties.isEnabled() && supertonicTtsClient.isAvailable();
  }

  /// 같은 단계는 한 번만 합성 (먼저 온 요청이 시작, 나머지는 같은 결과를 기다림)
  private Optional<FilledSpeech> synthesizeOnce(String stepId) {
    CompletableFuture<Optional<FilledSpeech>> myFuture = new CompletableFuture<>();
    CompletableFuture<Optional<FilledSpeech>> runningFuture = inFlightByStepId.putIfAbsent(stepId, myFuture);
    if (runningFuture != null) {
      return awaitResult(stepId, runningFuture);
    }
    if (!startSynthesis(stepId, myFuture)) {
      return Optional.empty();
    }
    return awaitResult(stepId, myFuture);
  }

  /// 상한 안이면 합성 작업 시작. 상한 초과·거부면 false (진행 표식 정리, 기다리던 요청에 빈 값)
  private boolean startSynthesis(String stepId, CompletableFuture<Optional<FilledSpeech>> future) {
    if (!synthesisPermits.tryAcquire()) {
      log.warn("[routine speech] on-demand skipped : stepId={}, reason=concurrency limit", stepId);
      abandon(stepId, future);
      return false;
    }
    try {
      executor.execute(() -> {
        try {
          future.complete(routineStepSpeechFiller.fillOnDemand(stepId));
        } catch (RuntimeException e) {
          future.complete(Optional.empty());
        } finally {
          // 작업 끝 (성공·실패·시간 초과 후 공통)
          synthesisPermits.release();
          inFlightByStepId.remove(stepId, future);
        }
      });
      return true;
    } catch (RejectedExecutionException e) {
      synthesisPermits.release();
      log.warn("[routine speech] on-demand skipped : stepId={}, reason=executor rejected", stepId);
      abandon(stepId, future);
      return false;
    }
  }

  private void abandon(String stepId, CompletableFuture<Optional<FilledSpeech>> future) {
    inFlightByStepId.remove(stepId, future);
    future.complete(Optional.empty());
  }

  /// 결과 대기 (시간 초과·실패는 빈 값, 시간 초과해도 합성은 끝까지 가서 저장되면 다음 요청이 저장본을 받음)
  private Optional<FilledSpeech> awaitResult(String stepId, CompletableFuture<Optional<FilledSpeech>> future) {
    try {
      return future.get(maxWait.toMillis(), TimeUnit.MILLISECONDS);
    } catch (TimeoutException e) {
      log.warn("[routine speech] on-demand timed out : stepId={}, waitMs={}", stepId, maxWait.toMillis());
      return Optional.empty();
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      return Optional.empty();
    } catch (ExecutionException e) {
      log.warn("[routine speech] on-demand failed : stepId={}, cause={}", stepId, e.getCause().getClass().getSimpleName());
      return Optional.empty();
    }
  }

  @PreDestroy
  void shutdown() {
    executor.shutdownNow();
  }
}
