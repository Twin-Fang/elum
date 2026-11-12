package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.admin.core.AdminPushOutcome;

/**
 * 관리자 알림 대상 미리 계산: 결과(READY·거절 사유), 대상 수, 알림 켠 사람 수, 기기 수, 상한, 지금 야간인지
 */
public record AdminPushPreviewResponse(
  String outcome,
  String message,
  String errorCode,
  int memberCount,
  int pushEnabledMemberCount,
  int deviceCount,
  int maximumRecipientCount,
  boolean isQuietHours
) {

  public static AdminPushPreviewResponse of(AdminPushOutcome outcome, int memberCount, int pushEnabledMemberCount,
    int deviceCount, int maximumRecipientCount, boolean isQuietHours) {
    return new AdminPushPreviewResponse(outcome.name(), outcome.getMessage(), outcome.getErrorCode(), memberCount,
      pushEnabledMemberCount, deviceCount, maximumRecipientCount, isQuietHours);
  }
}
