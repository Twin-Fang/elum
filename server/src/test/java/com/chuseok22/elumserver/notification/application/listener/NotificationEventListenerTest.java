package com.chuseok22.elumserver.notification.application.listener;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.member.application.service.ProfileGuardianService;
import com.chuseok22.elumserver.notification.application.service.NotificationRecorder;
import com.chuseok22.elumserver.notification.core.NotificationDraft;
import com.chuseok22.elumserver.notification.core.NotificationType;
import com.chuseok22.elumserver.notification.core.event.CoGuardianJoinedEvent;
import com.chuseok22.elumserver.notification.core.event.RoutineCompletedEvent;
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

  private NotificationEventListener listener;

  @BeforeEach
  void setUp() {
    Clock fixedClock = Clock.fixed(LocalDate.of(2026, 10, 19).atTime(10, 0).atZone(ZONE).toInstant(), ZONE);
    listener = new NotificationEventListener(notificationRecorder, profileGuardianService, fixedClock);
  }

  @Test
  @DisplayName("보호자 기기가 완료하면 그 보호자만 빼고, 이룸이 기기가 완료하면(actor null) 연결해 준 보호자까지 모두 받는다")
  void routineCompleted_excludesActor_includesLinkingGuardianWhenActorNull() {
    when(profileGuardianService.guardianMemberIdsOf("profile-1")).thenReturn(List.of("member-1", "member-2"));
    LocalDate routineDate = LocalDate.of(2026, 10, 19);

    listener.onRoutineCompleted(new RoutineCompletedEvent("routine-1", "profile-1", routineDate, "member-1"));
    listener.onRoutineCompleted(new RoutineCompletedEvent("routine-1", "profile-1", routineDate, null));

    ArgumentCaptor<Collection<String>> recipients = ArgumentCaptor.forClass(Collection.class);
    verify(notificationRecorder, org.mockito.Mockito.times(2)).record(any(NotificationDraft.class),
      recipients.capture());
    org.assertj.core.api.Assertions.assertThat(recipients.getAllValues().get(0)).containsExactly("member-2");
    org.assertj.core.api.Assertions.assertThat(recipients.getAllValues().get(1))
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
    org.assertj.core.api.Assertions.assertThat(draft.getValue().type()).isEqualTo(NotificationType.CO_GUARDIAN_JOINED);
    org.assertj.core.api.Assertions.assertThat(recipients.getValue()).containsExactly("member-1");
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
}
