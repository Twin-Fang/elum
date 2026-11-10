package com.chuseok22.elumserver.routine.infrastructure.scheduler;

import com.chuseok22.elumserver.routine.application.service.RoutineMemoryExtractor;
import com.chuseok22.elumserver.systemconfig.application.service.MigrationLock;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * AI 메모리 놓친 것 줍기: 30분마다 확정 직후 비동기 찾기가 놓친 일과(재시작·실패 직전 종료)를 찾음
 * 평소 찾기는 확정 직후 비동기가 하고, 여기는 안전망 (일과 하나는 한 번만 처리됨)
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class RoutineMemoryMissedScheduler {

  private final RoutineMemoryExtractor routineMemoryExtractor;
  private final MigrationLock migrationLock;

  // 30분 간격, 기동 5분 뒤 시작 (블루그린 전환 중 두 서버가 겹쳐도 일과 선점으로 한 번만 처리)
  @Scheduled(
    fixedDelayString = "${elum.routine.memory-build-delay-ms:1800000}",
    initialDelayString = "${elum.routine.memory-build-initial-delay-ms:300000}")
  public void run() {
    if (migrationLock.isBlockingScheduledJob("RoutineMemoryMissedScheduler")) {
      return;
    }
    try {
      int pickedCount = routineMemoryExtractor.extractMissed();
      if (pickedCount > 0) {
        log.info("[routine memory] missed extraction run done : picked={}", pickedCount);
      }
    } catch (RuntimeException e) {
      log.error("[routine memory] scheduled run failed, retry next run", e);
    }
  }
}
