package com.chuseok22.elumserver.notification.infrastructure.scheduler;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.credit.application.service.CreditQueryService;
import com.chuseok22.elumserver.credit.core.CreditPeriod;
import com.chuseok22.elumserver.notification.application.service.NotificationRecorder;
import com.chuseok22.elumserver.notification.application.service.PushDispatcher;
import com.chuseok22.elumserver.notification.application.service.RecordedNotification;
import com.chuseok22.elumserver.notification.core.NotificationDraft;
import com.chuseok22.elumserver.notification.core.NotificationType;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.stream.IntStream;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 결함: 다 쓴 보호자에게 알림이 안 가거나, 재실행 때 같은 알림이 중복되거나, 스케줄러 예외가 번진다
 */
@ExtendWith(MockitoExtension.class)
class CreditRefillNotificationSchedulerTest {

  /// 2026-10-19(월) 09:00 한국 시각 — 이번 주기 2026-W43, 지난 주기 2026-W42
  private static final Clock CLOCK = Clock.fixed(Instant.parse("2026-10-19T00:00:00Z"), ZoneId.of("Asia/Seoul"));
  private static final LocalDateTime NOW = LocalDateTime.of(2026, 10, 19, 9, 0);

  @Mock private CreditQueryService creditQueryService;
  @Mock private NotificationRecorder notificationRecorder;
  @Mock private PushDispatcher pushDispatcher;

  private CreditRefillNotificationScheduler scheduler;

  @BeforeEach
  void setUp() {
    scheduler = new CreditRefillNotificationScheduler(creditQueryService, notificationRecorder, pushDispatcher, CLOCK);
  }

  @Test
  @DisplayName("recordsOncePerMember_usingCurrentPeriodKey")
  void recordsOncePerMember_usingCurrentPeriodKey() {
    CreditPeriod previousPeriod = CreditPeriod.of(NOW.minusWeeks(1));
    List<RecordedNotification> recorded = List.of(new RecordedNotification("n1", "m1", 1, true));
    when(creditQueryService.memberIdsDepletedIn(previousPeriod)).thenReturn(List.of("m1", "m2"));
    when(notificationRecorder.record(any(NotificationDraft.class), eq(List.of("m1", "m2")))).thenReturn(recorded);

    scheduler.run();

    ArgumentCaptor<NotificationDraft> draft = ArgumentCaptor.forClass(NotificationDraft.class);
    verify(notificationRecorder).record(draft.capture(), eq(List.of("m1", "m2")));
    org.assertj.core.api.Assertions.assertThat(draft.getValue().groupKey()).isEqualTo("CREDIT_REFILLED:2026-W43");
    verify(pushDispatcher).dispatch(recorded, NotificationType.CREDIT_REFILLED);
  }

  @Test
  @DisplayName("runTwice_noDuplicatePush")
  void runTwice_noDuplicatePush() {
    List<RecordedNotification> first = List.of(new RecordedNotification("n1", "m1", 1, true));
    List<RecordedNotification> second = List.of(new RecordedNotification("n1", "m1", 1, false));
    when(creditQueryService.memberIdsDepletedIn(any(CreditPeriod.class))).thenReturn(List.of("m1"));
    when(notificationRecorder.record(any(NotificationDraft.class), anyCollection())).thenReturn(first, second);

    scheduler.run();
    scheduler.run();

    // 같은 묶음 키라 두 번째는 shouldPush=false — 기록 결과를 그대로 발송기에 넘김
    verify(pushDispatcher).dispatch(first, NotificationType.CREDIT_REFILLED);
    verify(pushDispatcher).dispatch(second, NotificationType.CREDIT_REFILLED);
  }

  @Test
  @DisplayName("recorderThrows_isLogged_notPropagated")
  void recorderThrows_isLogged_notPropagated() {
    when(creditQueryService.memberIdsDepletedIn(any(CreditPeriod.class))).thenReturn(List.of("m1"));
    when(notificationRecorder.record(any(NotificationDraft.class), anyCollection()))
      .thenThrow(new IllegalStateException("boom"));

    assertThatCode(() -> scheduler.run()).doesNotThrowAnyException();
    verify(pushDispatcher, never()).dispatch(any(), any());
  }

  @Test
  @DisplayName("noDepletedMembers_doesNothing")
  void noDepletedMembers_doesNothing() {
    when(creditQueryService.memberIdsDepletedIn(any(CreditPeriod.class))).thenReturn(List.of());

    scheduler.run();

    verifyNoInteractions(notificationRecorder, pushDispatcher);
  }

  @Test
  @DisplayName("manyMembers_recordedInChunksOf200")
  void manyMembers_recordedInChunksOf200() {
    List<String> memberIds = IntStream.range(0, 450).mapToObj(index -> "m" + index).toList();
    when(creditQueryService.memberIdsDepletedIn(any(CreditPeriod.class))).thenReturn(memberIds);
    when(notificationRecorder.record(any(NotificationDraft.class), anyCollection())).thenReturn(List.of());

    scheduler.run();

    verify(notificationRecorder, org.mockito.Mockito.times(3)).record(any(NotificationDraft.class), anyCollection());
  }
}
