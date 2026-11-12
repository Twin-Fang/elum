package com.chuseok22.elumserver.notification.infrastructure.scheduler;

import com.chuseok22.elumserver.notification.application.service.AutoNotificationRunner;
import com.chuseok22.elumserver.notification.core.NotificationTime;
import com.chuseok22.elumserver.systemconfig.application.service.MigrationLock;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 자동 알림 스케줄 (#1275): 서버 이전 잠금 확인 > AutoNotificationRunner 한 번 (야간·시각·상한 판단은 그쪽)
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class AutoNotificationScheduler {

  private final AutoNotificationRunner autoNotificationRunner;
  private final MigrationLock migrationLock;

  // 10분마다 (한국 시각). 정한 시각 이후 첫 실행에서 그날 한 번 보냄
  @Scheduled(cron = "${elum.notification.auto-cron:0 */10 * * * *}", zone = NotificationTime.ZONE_ID_NAME)
  public void run() {
    if (migrationLock.isBlockingScheduledJob("AutoNotificationScheduler")) {
      return;
    }
    try {
      autoNotificationRunner.runOnce();
    } catch (RuntimeException exception) {
      // 스케줄러 밖으로 던지지 않음
      log.warn("[auto notification] run failed : {}", exception.getClass().getSimpleName());
      log.debug("[auto notification] failure detail", exception);
    }
  }
}
