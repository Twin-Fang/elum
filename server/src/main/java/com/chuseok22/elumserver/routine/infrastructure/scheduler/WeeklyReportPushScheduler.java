package com.chuseok22.elumserver.routine.infrastructure.scheduler;

import com.chuseok22.elumserver.notification.core.NotificationTime;
import com.chuseok22.elumserver.routine.application.service.WeeklyReportPushService;
import com.chuseok22.elumserver.systemconfig.application.service.MigrationLock;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 주간 리포트 월요일 알림 예약 작업: 월요일 한국 시각 8시부터 10시까지 매시 정각
 * 첫 실행이 건수 상한에 막혀 남긴 이룸이를 다음 실행이 잇고, 이미 보낸 이룸이는 알림 묶음 키가 다시 보내지 않음
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class WeeklyReportPushScheduler {

  private final WeeklyReportPushService weeklyReportPushService;
  private final MigrationLock migrationLock;

  @Scheduled(cron = "${elum.routine.weekly-report-push-cron:0 0 8-10 * * MON}", zone = NotificationTime.ZONE_ID_NAME)
  public void run() {
    if (migrationLock.isBlockingScheduledJob("WeeklyReportPushScheduler")) {
      return;
    }
    try {
      weeklyReportPushService.runOnce();
    } catch (RuntimeException e) {
      // 스케줄러 밖으로 던지지 않음 (다음 실행이 이어서 처리)
      log.error("[weekly report] scheduled push run failed", e);
    }
  }
}
