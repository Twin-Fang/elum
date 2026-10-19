package com.chuseok22.elumserver.notification.core;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * 알림 한 건의 발생 내용: 종류, 이룸이, 눌렀을 때 갈 대상, 묶음 키, 묶음에 모을 대상 id, 발생 시각
 * 묶음 키 규칙은 정적 팩토리 5개에 고정 (같은 키 = 같은 줄)
 */
public record NotificationDraft(
  NotificationType type,
  String profileId,
  String targetId,
  String groupKey,
  String subjectId,
  LocalDateTime occurredAt
) {

  private static final DateTimeFormatter GROUP_DATE_FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd");

  /** 일과 완료: 이룸이·날짜별로 한 줄, 일과 id 를 모은다 (ROUTINE_COMPLETED:{profileId}:{yyyy-MM-dd}) */
  public static NotificationDraft routineCompleted(String profileId, String routineId, LocalDate routineDate,
    LocalDateTime now) {
    String groupKey = "ROUTINE_COMPLETED:" + profileId + ":" + GROUP_DATE_FORMAT.format(routineDate);
    return new NotificationDraft(NotificationType.ROUTINE_COMPLETED, profileId, routineId, groupKey, routineId, now);
  }

  /** 공동 보호자가 보낸 일과: 일과마다 한 줄 (ROUTINE_SENT:{routineId}) */
  public static NotificationDraft routineSent(String profileId, String routineId, LocalDateTime now) {
    return new NotificationDraft(NotificationType.ROUTINE_SENT_BY_CO_GUARDIAN, profileId, routineId,
      "ROUTINE_SENT:" + routineId, null, now);
  }

  /** 공동 보호자 합류: 합류한 사람마다 한 줄 (CO_GUARDIAN_JOINED:{profileId}:{joinedMemberId}) */
  public static NotificationDraft coGuardianJoined(String profileId, String joinedMemberId, LocalDateTime now) {
    return new NotificationDraft(NotificationType.CO_GUARDIAN_JOINED, profileId, null,
      "CO_GUARDIAN_JOINED:" + profileId + ":" + joinedMemberId, null, now);
  }

  /** 크레딧 충전: 충전 주기마다 한 줄, 이룸이와 무관 (CREDIT_REFILLED:{periodKey}) */
  public static NotificationDraft creditRefilled(String periodKey, LocalDateTime now) {
    return new NotificationDraft(NotificationType.CREDIT_REFILLED, null, null,
      "CREDIT_REFILLED:" + periodKey, null, now);
  }

  /** 의견 처리: 의견마다 한 줄 (FEEDBACK_RESOLVED:{feedbackId}) */
  public static NotificationDraft feedbackResolved(String feedbackId, LocalDateTime now) {
    return new NotificationDraft(NotificationType.FEEDBACK_RESOLVED, null, feedbackId,
      "FEEDBACK_RESOLVED:" + feedbackId, null, now);
  }
}
