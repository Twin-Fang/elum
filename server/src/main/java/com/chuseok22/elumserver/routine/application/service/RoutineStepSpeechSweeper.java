package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 빠진 단계 음성 메우기 (#675): 실패분, AI 서버가 꺼졌던 동안 만든 일과, 기능 이전 일과
 * 2분마다, 대기열이 비었을 때만, 한국어 단계 최대 20건
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class RoutineStepSpeechSweeper {

  // 한 번에 대기열에 넣는 최대 건수 (실측 한 건 2.3~3.5초 > 2분 안에 처리되는 양)
  static final int SWEEP_BATCH_SIZE = 20;
  // 실패해 쉬는 단계를 건너뛰고도 채울 수 있게 넉넉히 조회
  private static final int SWEEP_LOOKUP_SIZE = SWEEP_BATCH_SIZE * 3;

  private final RoutineStepRepository routineStepRepository;
  private final RoutineStepSpeechQueue routineStepSpeechQueue;

  @Scheduled(fixedDelayString = "PT2M", initialDelayString = "PT1M")
  public void sweep() {
    // 꺼져 있거나 이전 분량을 처리 중이면 건너뜀
    if (!routineStepSpeechQueue.isEnabled() || routineStepSpeechQueue.pendingCount() > 0) {
      return;
    }
    try {
      List<String> stepIds = routineStepRepository
        .findIdsMissingSpeech(AppLocale.KO, PageRequest.of(0, SWEEP_LOOKUP_SIZE)).stream()
        .filter(stepId -> !routineStepSpeechQueue.isCoolingDown(stepId))
        .limit(SWEEP_BATCH_SIZE)
        .toList();
      if (stepIds.isEmpty()) {
        return;
      }
      stepIds.forEach(routineStepSpeechQueue::enqueue);
      log.info("[routine speech] sweep enqueued : count={}", stepIds.size());
    } catch (Exception e) {
      // 조회 실패해도 다음 주기에 다시 (스케줄러 스레드 보호)
      log.warn("[routine speech] sweep failed : cause={}", e.getClass().getSimpleName(), e);
    }
  }
}
