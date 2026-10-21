package com.chuseok22.elumserver.notification.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.notification.infrastructure.entity.Notification;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

/// 남의 알림을 읽음 처리할 수 있으면 다른 보호자의 배지가 사라지고, 전체 읽음이 남의 것까지 건드리면 알림이 유실된다
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class NotificationReadServiceTest {

  private static final ZoneId ZONE = ZoneId.of("Asia/Seoul");
  private static final Clock CLOCK = Clock.fixed(Instant.parse("2026-10-19T03:00:00Z"), ZONE);

  @Mock
  private NotificationRepository notificationRepository;

  private NotificationReadService notificationReadService;

  @BeforeEach
  void setUp() {
    notificationReadService = new NotificationReadService(notificationRepository, CLOCK);
  }

  @Test
  @DisplayName("남의 알림을 읽음 처리하면 NOTIFICATION_NOT_FOUND 로 거절하고 읽음 시각을 바꾸지 않는다")
  void readOthersNotification_throwsNotFound() {
    Notification others = new Notification();
    others.setRecipientMemberId("other-member");
    when(notificationRepository.findById("n1")).thenReturn(Optional.of(others));

    assertThatThrownBy(() -> notificationReadService.markRead("m1", "n1"))
      .isInstanceOf(CustomException.class)
      .extracting(e -> ((CustomException) e).getErrorCode())
      .isEqualTo(ErrorCode.NOTIFICATION_NOT_FOUND);
    assertThat(others.getReadAt()).isNull();
  }

  @Test
  @DisplayName("없는 알림도 같은 NOTIFICATION_NOT_FOUND 이다")
  void readMissingNotification_throwsNotFound() {
    when(notificationRepository.findById("none")).thenReturn(Optional.empty());

    assertThatThrownBy(() -> notificationReadService.markRead("m1", "none"))
      .isInstanceOf(CustomException.class);
  }

  @Test
  @DisplayName("내 알림은 읽은 시각을 지금으로 기록한다")
  void readOwnNotification_setsReadAt() {
    Notification mine = new Notification();
    mine.setRecipientMemberId("m1");
    when(notificationRepository.findById("n1")).thenReturn(Optional.of(mine));

    notificationReadService.markRead("m1", "n1");

    assertThat(mine.getReadAt()).isEqualTo(LocalDateTime.now(CLOCK));
  }

  @Test
  @DisplayName("전체 읽음은 내 회원 id 로만 처리한다")
  void readAll_marksOnlyMine() {
    notificationReadService.markAllRead("m1");

    verify(notificationRepository).markAllRead(eq("m1"), eq(LocalDateTime.now(CLOCK)));
    verify(notificationRepository, never()).markAllRead(eq("other-member"), any());
  }
}
