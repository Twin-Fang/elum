package com.chuseok22.elumserver.notification.infrastructure.scheduler;

import static org.mockito.Mockito.verify;

import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 결함: 보관 기간 계산이 틀리면 알림이 너무 일찍 지워지거나 영영 쌓인다
 */
@ExtendWith(MockitoExtension.class)
class NotificationRetentionSchedulerTest {

  private static final Clock CLOCK = Clock.fixed(Instant.parse("2026-10-20T20:00:00Z"), ZoneId.of("Asia/Seoul"));

  @Mock private NotificationRepository notificationRepository;

  @Test
  @DisplayName("deletesOlderThan90Days")
  void deletesOlderThan90Days() {
    new NotificationRetentionScheduler(notificationRepository, CLOCK).run();

    // 2026-10-21 05:00 KST - 90일
    verify(notificationRepository).deleteAllByLastOccurredAtBefore(LocalDateTime.of(2026, 10, 21, 5, 0).minusDays(90));
  }
}
