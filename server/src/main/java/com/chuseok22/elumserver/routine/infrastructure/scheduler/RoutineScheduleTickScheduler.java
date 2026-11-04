package com.chuseok22.elumserver.routine.infrastructure.scheduler;

import com.chuseok22.elumserver.notification.core.NotificationTime;
import com.chuseok22.elumserver.routine.application.service.RoutineScheduleRunner;
import com.chuseok22.elumserver.systemconfig.application.service.MigrationLock;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 반복 일과 1분 작업 (#1080): 정한 시각이 된 예약 > 오늘 일과 만들기 + 이룸이 기기 알림
 * 같은 날 중복은 예약 행 날짜 차지로 막아 서버 둘(블루·그린)이 함께 돌아도 한 번만 울림
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class RoutineScheduleTickScheduler {

  private final RoutineScheduleRunner routineScheduleRunner;
  private final MigrationLock migrationLock;

  // 매분 0초 (한국 시각)
  @Scheduled(cron = "${elum.routine.schedule-tick-cron:0 * * * * *}", zone = NotificationTime.ZONE_ID_NAME)
  public void run() {
    if (migrationLock.isBlockingScheduledJob("RoutineScheduleTickScheduler")) {
      return;
    }
    try {
      routineScheduleRunner.notifyDue();
    } catch (RuntimeException exception) {
      // 스케줄러 밖으로 던지지 않음 (다음 분은 그대로 돎)
      log.warn("[routine schedule] tick failed : {}", exception.getClass().getSimpleName());
      log.debug("[routine schedule] tick failure detail", exception);
    }
  }
}
