package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.admin.core.AdminPushOutcome;
import com.chuseok22.elumserver.notification.application.service.AdminMessageSendResult;

/**
 * 관리자 알림 보낸 결과: 결과(SENT·거절 사유), 운영자 알림 id, 대상 수, 알림함 기록 수, 기기 성공·실패 수
 */
public record AdminPushSendResponse(
  String outcome,
  String message,
  String errorCode,
  String messageId,
  int recipientCount,
  int recordedMemberCount,
  int sentDeviceCount,
  int failedDeviceCount
) {

  public static AdminPushSendResponse rejected(AdminPushOutcome outcome) {
    return new AdminPushSendResponse(outcome.name(), outcome.getMessage(), outcome.getErrorCode(), null, 0, 0, 0, 0);
  }

  public static AdminPushSendResponse sent(int recipientCount, AdminMessageSendResult result) {
    AdminPushOutcome outcome = AdminPushOutcome.SENT;
    return new AdminPushSendResponse(outcome.name(), outcome.getMessage(), null, result.messageId(), recipientCount,
      result.recordedMemberCount(), result.sentDeviceCount(), result.failedDeviceCount());
  }
}
