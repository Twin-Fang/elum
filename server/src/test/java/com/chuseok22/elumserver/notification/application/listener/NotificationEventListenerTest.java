package com.chuseok22.elumserver.notification.application.listener;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.member.application.service.ProfileGuardianService;
import com.chuseok22.elumserver.notification.application.service.NotificationRecorder;
import com.chuseok22.elumserver.notification.application.service.PushDispatcher;
import com.chuseok22.elumserver.notification.application.service.RecordedNotification;
import com.chuseok22.elumserver.notification.core.NotificationDraft;
import com.chuseok22.elumserver.notification.core.NotificationType;
import com.chuseok22.elumserver.notification.core.event.CoGuardianJoinedEvent;
import com.chuseok22.elumserver.notification.core.event.FeedbackResolvedEvent;
import com.chuseok22.elumserver.notification.core.event.RoutineCompletedEvent;
import com.chuseok22.elumserver.notification.core.event.RoutineSentEvent;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.Collection;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/// 받는 사람 계산(요청자 제외)과 실패 격리: 이벤트를 잘못 계산하면 요청자 본인에게 알림이 가거나 요청이 실패한다
@ExtendWith(MockitoExtension.class)
class NotificationEventListenerTest {

  private static final ZoneId ZONE = ZoneId.of("Asia/Seoul");

  @Mock
  private NotificationRecorder notificationRecorder;
  @Mock
  private ProfileGuardianService profileGuardianService;
  @Mock
  private PushDispatcher pushDispatcher;

  private NotificationEventListener listener;

  @BeforeEach
  void setUp() {
    Clock fixedClock = Clock.fixed(LocalDate.of(2026, 10, 19).atTime(10, 0).atZone(ZONE).toInstant(), ZONE);
    listener = new NotificationEventListener(notificationRecorder, profileGuardianService, pushDispatcher, fixedClock);
  }

  @Test
  @DisplayName("보호자 기기가 완료하면 그 보호자만 빼고, 이룸이 기기가 완료하면(actor null) 연결해 준 보호자까지 모두 받는다")
  void routineCompleted_excludesActor_includesLinkingGuardianWhenActorNull() {
    when(profileGuardianService.guardianMemberIdsOf("profile-1")).thenReturn(List.of("member-1", "member-2"));
    LocalDate routineDate = LocalDate.of(2026, 10, 19);

    listener.onRoutineCompleted(new RoutineCompletedEvent("routine-1", "profile-1", routineDate, "member-1"));
    listener.onRoutineCompleted(new RoutineCompletedEvent("routine-1", "profile-1", routineDate, null));

    ArgumentCaptor<Collection<String>> recipients = ArgumentCaptor.forClass(Collection.class);
    verify(notificationRecorder, times(2)).record(any(NotificationDraft.class),
      recipients.capture());
    assertThat(recipients.getAllValues().get(0)).containsExactly("member-2");
    assertThat(recipients.getAllValues().get(1))
      .containsExactly("member-1", "member-2");
  }

  @Test
  @DisplayName("합류 알림은 합류한 본인을 뺀 기존 보호자에게 간다")
  void coGuardianJoined_excludesJoinedMember() {
    when(profileGuardianService.guardianMemberIdsOf("profile-1")).thenReturn(List.of("member-1", "member-2"));

    listener.onCoGuardianJoined(new CoGuardianJoinedEvent("profile-1", "member-2"));

    ArgumentCaptor<NotificationDraft> draft = ArgumentCaptor.forClass(NotificationDraft.class);
    ArgumentCaptor<Collection<String>> recipients = ArgumentCaptor.forClass(Collection.class);
    verify(notificationRecorder).record(draft.capture(), recipients.capture());
    assertThat(draft.getValue().type()).isEqualTo(NotificationType.CO_GUARDIAN_JOINED);
    assertThat(recipients.getValue()).containsExactly("member-1");
  }

  @Test
  @DisplayName("일과 보냄 알림은 보낸 보호자를 뺀 나머지 보호자에게 간다")
  void routineSent_excludesActor() {
    when(profileGuardianService.guardianMemberIdsOf("profile-1")).thenReturn(List.of("member-1", "member-2"));

    listener.onRoutineSent(new RoutineSentEvent("routine-1", "profile-1", "member-1"));

    ArgumentCaptor<NotificationDraft> draft = ArgumentCaptor.forClass(NotificationDraft.class);
    ArgumentCaptor<Collection<String>> recipients = ArgumentCaptor.forClass(Collection.class);
    verify(notificationRecorder).record(draft.capture(), recipients.capture());
    assertThat(draft.getValue().type()).isEqualTo(NotificationType.ROUTINE_SENT_BY_CO_GUARDIAN);
    assertThat(recipients.getValue()).containsExactly("member-2");
  }

  @Test
  @DisplayName("의견 처리 알림은 보호자 조회 없이 의견을 보낸 한 명에게만 간다")
  void feedbackResolved_recordsForFeedbackOwnerOnly() {
    listener.onFeedbackResolved(new FeedbackResolvedEvent("feedback-1", "member-9"));

    ArgumentCaptor<NotificationDraft> draft = ArgumentCaptor.forClass(NotificationDraft.class);
    ArgumentCaptor<Collection<String>> recipients = ArgumentCaptor.forClass(Collection.class);
    verify(notificationRecorder).record(draft.capture(), recipients.capture());
    assertThat(draft.getValue().type()).isEqualTo(NotificationType.FEEDBACK_RESOLVED);
    assertThat(recipients.getValue()).containsExactly("member-9");
    verifyNoInteractions(profileGuardianService);
  }

  @Test
  @DisplayName("기록이 예외를 던져도 리스너 밖으로 번지지 않는다")
  void recorderThrows_doesNotPropagate() {
    when(profileGuardianService.guardianMemberIdsOf("profile-1")).thenReturn(List.of("member-1"));
    when(notificationRecorder.record(any(NotificationDraft.class), anyCollection()))
      .thenThrow(new IllegalStateException("db down"));

    assertThatCode(() -> listener.onRoutineCompleted(
      new RoutineCompletedEvent("routine-1", "profile-1", LocalDate.of(2026, 10, 19), null)))
      .doesNotThrowAnyException();
  }

  @Test
  @DisplayName("기록이 끝나면 기록 결과와 종류로 푸시 발송을 부른다")
  void recorded_thenDispatchCalled() {
    List<RecordedNotification> recorded = List.of(new RecordedNotification("n1", "member-2", 1, true));
    when(profileGuardianService.guardianMemberIdsOf("profile-1")).thenReturn(List.of("member-2"));
    when(notificationRecorder.record(any(NotificationDraft.class), anyCollection())).thenReturn(recorded);

    listener.onRoutineCompleted(new RoutineCompletedEvent("routine-1", "profile-1", LocalDate.of(2026, 10, 19), null));

    verify(pushDispatcher).dispatch(recorded, NotificationType.ROUTINE_COMPLETED);
  }

  @Test
  @DisplayName("푸시 발송이 예외를 던져도 리스너 밖으로 번지지 않는다")
  void dispatchThrows_notPropagated() {
    when(profileGuardianService.guardianMemberIdsOf("profile-1")).thenReturn(List.of("member-2"));
    doThrow(new IllegalStateException("fcm down")).when(pushDispatcher).dispatch(any(), any());

    assertThatCode(() -> listener.onRoutineCompleted(
      new RoutineCompletedEvent("routine-1", "profile-1", LocalDate.of(2026, 10, 19), null)))
      .doesNotThrowAnyException();
  }
}
