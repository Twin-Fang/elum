package com.chuseok22.elumserver.notification.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.notification.infrastructure.entity.NotificationDispatch;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationDispatchRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 남의 발송 기록을 열림 처리하거나 두 번째 열림이 첫 시각을 덮으면 열림률이 틀어진다 (#1275)
class NotificationDispatchServiceTest {

  private final NotificationDispatchRepository repository = mock(NotificationDispatchRepository.class);
  private final NotificationDispatchService service = new NotificationDispatchService(repository,
    Clock.fixed(Instant.parse("2026-11-12T01:00:00Z"), ZoneId.of("Asia/Seoul")));

  @Test
  @DisplayName("내 기록은 처음 연 시각을 남기고, 다시 불러도 첫 시각을 그대로 둔다")
  void markOpened_ownDispatch_keepsFirstOpenTime() {
    NotificationDispatch dispatch = dispatchOf("m1");
    when(repository.findById("d1")).thenReturn(Optional.of(dispatch));

    service.markOpened("m1", "d1");
    assertThat(dispatch.getOpenedAt()).isEqualTo(LocalDateTime.parse("2026-11-12T10:00"));

    dispatch.setOpenedAt(LocalDateTime.parse("2026-11-12T09:30"));
    service.markOpened("m1", "d1");
    assertThat(dispatch.getOpenedAt()).isEqualTo(LocalDateTime.parse("2026-11-12T09:30"));
  }

  @Test
  @DisplayName("남의 기록·없는 기록은 같은 NOTIFICATION_NOT_FOUND 이고 열림을 남기지 않는다")
  void markOpened_otherMemberOrMissing_notFound() {
    NotificationDispatch others = dispatchOf("m2");
    when(repository.findById("d-other")).thenReturn(Optional.of(others));
    when(repository.findById("d-missing")).thenReturn(Optional.empty());

    assertThatThrownBy(() -> service.markOpened("m1", "d-other"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode()).isEqualTo(ErrorCode.NOTIFICATION_NOT_FOUND));
    assertThatThrownBy(() -> service.markOpened("m1", "d-missing"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode()).isEqualTo(ErrorCode.NOTIFICATION_NOT_FOUND));
    assertThat(others.getOpenedAt()).isNull();
  }

  private static NotificationDispatch dispatchOf(String memberId) {
    NotificationDispatch dispatch = new NotificationDispatch();
    dispatch.setMemberId(memberId);
    return dispatch;
  }
}
