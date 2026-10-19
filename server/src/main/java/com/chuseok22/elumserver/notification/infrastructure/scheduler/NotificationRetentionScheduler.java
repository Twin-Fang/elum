package com.chuseok22.elumserver.notification.infrastructure.scheduler;

import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationRepository;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneId;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * 알림 보관 정리: 마지막 발생이 90일 지난 알림 삭제
 */
@Slf4j
@Component
public class NotificationRetentionScheduler {

  private static final ZoneId NOTIFICATION_ZONE = ZoneId.of("Asia/Seoul");
  // 알림 보관 기간 (90일)
  private static final int RETENTION_DAYS = 90;

  private final NotificationRepository notificationRepository;
  private final Clock clock;

  @Autowired
  public NotificationRetentionScheduler(NotificationRepository notificationRepository) {
    this(notificationRepository, Clock.system(NOTIFICATION_ZONE));
  }

  NotificationRetentionScheduler(NotificationRepository notificationRepository, Clock clock) {
    this.notificationRepository = notificationRepository;
    this.clock = clock;
  }

  // 새벽 5시(한국 시각)
  @Scheduled(cron = "${elum.notification.retention-cron:0 0 5 * * *}", zone = "Asia/Seoul")
  @Transactional
  public void run() {
    int deletedCount = notificationRepository.deleteAllByLastOccurredAtBefore(
      LocalDateTime.now(clock).minusDays(RETENTION_DAYS));
    log.info("[notification retention] deleted {}", deletedCount);
  }
}
