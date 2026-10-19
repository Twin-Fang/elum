package com.chuseok22.elumserver.notification.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.notification.core.NotificationDraft;
import com.chuseok22.elumserver.notification.infrastructure.entity.Notification;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationRepository;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.dao.DataIntegrityViolationException;

/**
 * 알림 묶음 규칙: 같은 날 다른 일과는 한 줄로 모이고(횟수 +1, 다시 안 읽음), 같은 일과·묶음 없는 종류는 푸시하지 않는다.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class NotificationRecorderTest {

  private static final LocalDate DAY = LocalDate.of(2026, 10, 19);
  private static final LocalDateTime FIRST_AT = LocalDateTime.of(2026, 10, 19, 9, 0);
  private static final LocalDateTime SECOND_AT = LocalDateTime.of(2026, 10, 19, 10, 0);

  @Mock private NotificationRepository notificationRepository;

  private NotificationRecorder recorder;

  @BeforeEach
  void setUp() {
    recorder = new NotificationRecorder(new NotificationRowWriter(notificationRepository));
    when(notificationRepository.saveAndFlush(any(Notification.class))).thenAnswer(call -> {
      Notification row = call.getArgument(0);
      if (row.getId() == null) {
        row.setId("n1");
      }
      return row;
    });
  }

  private Notification existingCompletedRow(String subjectIds, int count) {
    Notification row = new Notification();
    row.setId("n1");
    row.setRecipientMemberId("A");
    row.setGroupKey("ROUTINE_COMPLETED:p1:2026-10-19");
    row.setSubjectIds(subjectIds);
    row.setCount(count);
    row.setLastOccurredAt(FIRST_AT);
    row.setReadAt(FIRST_AT);
    return row;
  }

  @Test
  @DisplayName("첫 완료는 count 1 로 새 줄을 만들고 푸시 대상이다")
  void firstCompletion_createsRowWithCount1_andShouldPush() {
    when(notificationRepository.findForUpdateByRecipientMemberIdAndGroupKey("A", "ROUTINE_COMPLETED:p1:2026-10-19"))
      .thenReturn(Optional.empty());

    List<RecordedNotification> result =
      recorder.record(NotificationDraft.routineCompleted("p1", "r1", DAY, FIRST_AT), List.of("A"));

    assertThat(result).hasSize(1);
    assertThat(result.get(0).count()).isEqualTo(1);
    assertThat(result.get(0).shouldPush()).isTrue();
  }

  @Test
  @DisplayName("같은 날 다른 일과 완료는 같은 줄을 count 2 로 올리고 다시 안 읽음으로 돌리며 푸시한다")
  void secondDifferentRoutineSameDay_updatesSameRow_count2_unreadAgain_shouldPush() {
    Notification row = existingCompletedRow("r1", 1);
    when(notificationRepository.findForUpdateByRecipientMemberIdAndGroupKey("A", row.getGroupKey()))
      .thenReturn(Optional.of(row));

    List<RecordedNotification> result =
      recorder.record(NotificationDraft.routineCompleted("p1", "r2", DAY, SECOND_AT), List.of("A"));

    assertThat(result.get(0).count()).isEqualTo(2);
    assertThat(result.get(0).shouldPush()).isTrue();
    assertThat(row.getReadAt()).isNull();
    assertThat(row.getLastOccurredAt()).isEqualTo(SECOND_AT);
    assertThat(row.getSubjectIds()).isEqualTo("r1,r2");
  }

  @Test
  @DisplayName("같은 일과를 다시 완료하면 횟수를 그대로 두고 푸시하지 않는다")
  void sameRoutineCompletedAgain_keepsCount_shouldNotPush() {
    Notification row = existingCompletedRow("r1", 1);
    when(notificationRepository.findForUpdateByRecipientMemberIdAndGroupKey("A", row.getGroupKey()))
      .thenReturn(Optional.of(row));

    List<RecordedNotification> result =
      recorder.record(NotificationDraft.routineCompleted("p1", "r1", DAY, SECOND_AT), List.of("A"));

    assertThat(result.get(0).count()).isEqualTo(1);
    assertThat(result.get(0).shouldPush()).isFalse();
  }

  @Test
  @DisplayName("의견 처리 알림은 두 번째부터 아무것도 하지 않고 푸시하지 않는다")
  void feedbackResolvedTwice_secondIsNoOp_shouldNotPush() {
    Notification row = new Notification();
    row.setId("n9");
    row.setRecipientMemberId("A");
    row.setGroupKey("FEEDBACK_RESOLVED:f1");
    row.setCount(1);
    when(notificationRepository.findForUpdateByRecipientMemberIdAndGroupKey("A", "FEEDBACK_RESOLVED:f1"))
      .thenReturn(Optional.empty(), Optional.of(row));

    RecordedNotification first =
      recorder.record(NotificationDraft.feedbackResolved("f1", FIRST_AT), List.of("A")).get(0);
    RecordedNotification second =
      recorder.record(NotificationDraft.feedbackResolved("f1", SECOND_AT), List.of("A")).get(0);

    assertThat(first.shouldPush()).isTrue();
    assertThat(second.shouldPush()).isFalse();
    assertThat(second.count()).isEqualTo(1);
  }

  @Test
  @DisplayName("동시에 같은 묶음을 만들어 중복 키 위반이 나면 다시 읽어 갱신한다")
  void uniqueViolationOnInsert_retriesAsUpdate() {
    Notification winner = existingCompletedRow("r1", 1);
    when(notificationRepository.findForUpdateByRecipientMemberIdAndGroupKey("A", winner.getGroupKey()))
      .thenReturn(Optional.empty(), Optional.of(winner));
    when(notificationRepository.saveAndFlush(any(Notification.class)))
      .thenThrow(new DataIntegrityViolationException("uk_notification_member_group"))
      .thenAnswer(call -> call.getArgument(0));

    List<RecordedNotification> result =
      recorder.record(NotificationDraft.routineCompleted("p1", "r2", DAY, SECOND_AT), List.of("A"));

    assertThat(result).hasSize(1);
    assertThat(result.get(0).count()).isEqualTo(2);
    assertThat(result.get(0).shouldPush()).isTrue();
  }

  @Test
  @DisplayName("한 사람의 기록이 실패해도 다른 사람은 기록되고 실패한 사람만 결과에서 빠진다")
  void oneRecipientFailing_doesNotStopOthers() {
    when(notificationRepository.findForUpdateByRecipientMemberIdAndGroupKey("A", "FEEDBACK_RESOLVED:f1"))
      .thenThrow(new IllegalStateException("db down"));
    when(notificationRepository.findForUpdateByRecipientMemberIdAndGroupKey("B", "FEEDBACK_RESOLVED:f1"))
      .thenReturn(Optional.empty());

    List<RecordedNotification> result =
      recorder.record(NotificationDraft.feedbackResolved("f1", FIRST_AT), List.of("A", "B"));

    assertThat(result).extracting(RecordedNotification::recipientMemberId).containsExactly("B");
  }

  @Test
  @DisplayName("기록 경로는 동시 갱신 유실을 막으려고 잠금(for update) 조회를 쓴다")
  void write_usesForUpdateLookup() {
    when(notificationRepository.findForUpdateByRecipientMemberIdAndGroupKey("A", "FEEDBACK_RESOLVED:f1"))
      .thenReturn(Optional.empty());

    recorder.record(NotificationDraft.feedbackResolved("f1", FIRST_AT), List.of("A"));

    verify(notificationRepository).findForUpdateByRecipientMemberIdAndGroupKey("A", "FEEDBACK_RESOLVED:f1");
  }
}
