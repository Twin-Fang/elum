package com.chuseok22.elumserver.routine.infrastructure.scheduler;

import com.chuseok22.elumserver.routine.application.service.RoutineMemoryBuilder;
import com.chuseok22.elumserver.systemconfig.application.service.MigrationLock;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * AI 메모 갱신 주기 (#1082): 30분마다 대기 이룸이를 훑음. 실제 AI 호출은 이룸이마다 하루 1번(또는 고친 일과 5개)
 * 확정 직후가 아니라 예약 작업에서 하는 이유: 확정·일과 만들기 응답을 늦추지 않고, 여러 확정을 한 호출로 묶음
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class RoutineMemoryBuildScheduler {

  private final RoutineMemoryBuilder routineMemoryBuilder;
  private final MigrationLock migrationLock;

  // 30분 간격, 기동 5분 뒤 시작 (블루그린 전환 중 두 서버가 겹쳐도 최악은 같은 이룸이 1회 중복 호출)
  @Scheduled(
    fixedDelayString = "${elum.routine.memory-build-delay-ms:1800000}",
    initialDelayString = "${elum.routine.memory-build-initial-delay-ms:300000}")
  public void run() {
    if (migrationLock.isBlockingScheduledJob("RoutineMemoryBuildScheduler")) {
      return;
    }
    try {
      routineMemoryBuilder.runOnce();
    } catch (RuntimeException e) {
      log.error("[routine memory] scheduled run failed, retry next run", e);
    }
  }
}
