package com.chuseok22.elumserver.notification.core;

/** 알림 종류 7개: 일과 완료, 공동 보호자가 보낸 일과, 공동 보호자 합류, 크레딧 충전, 의견 처리, 이야기 댓글, 이야기 가져감 */
public enum NotificationType {
  ROUTINE_COMPLETED,
  ROUTINE_SENT_BY_CO_GUARDIAN,
  CO_GUARDIAN_JOINED,
  CREDIT_REFILLED,
  FEEDBACK_RESOLVED,
  TALK_POST_COMMENTED,
  TALK_POST_IMPORTED
}
