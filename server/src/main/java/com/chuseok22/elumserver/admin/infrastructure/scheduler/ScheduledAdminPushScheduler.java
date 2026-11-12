package com.chuseok22.elumserver.admin.infrastructure.scheduler;

import com.chuseok22.elumserver.admin.application.service.AdminScheduledPushService;
import com.chuseok22.elumserver.notification.core.NotificationTime;
import com.chuseok22.elumserver.systemconfig.application.service.MigrationLock;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 예약 발송 스케줄 (#1275): 서버 이전 잠금 확인 > 보낼 차례 보내기 (야간·선점 판단은 AdminScheduledPushService)
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ScheduledAdminPushScheduler {

  private final AdminScheduledPushService adminScheduledPushService;
  private final MigrationLock migrationLock;

  // 1분마다 (한국 시각): 예약 시각과 1분 안팎으로 보냄
  @Scheduled(cron = "${elum.notification.scheduled-push-cron:0 * * * * *}", zone = NotificationTime.ZONE_ID_NAME)
  public void run() {
    if (migrationLock.isBlockingScheduledJob("ScheduledAdminPushScheduler")) {
      return;
    }
    try {
      adminScheduledPushService.sendDue();
    } catch (RuntimeException exception) {
      // 스케줄러 밖으로 던지지 않음
      log.warn("[scheduled push] run failed : {}", exception.getClass().getSimpleName());
      log.debug("[scheduled push] failure detail", exception);
    }
  }
}
