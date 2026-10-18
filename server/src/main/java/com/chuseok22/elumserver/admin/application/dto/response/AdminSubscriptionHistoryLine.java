package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.core.SubscriptionHistoryAction;
import com.chuseok22.elumserver.license.infrastructure.entity.SubscriptionHistory;
import java.time.LocalDateTime;

/**
 * 회원 상세의 요금제 이력 한 줄: 시각, 변경자, 부여/회수, 전/후 요금제, 기간, 사유
 */
public record AdminSubscriptionHistoryLine(
  LocalDateTime changedAt,
  String changedBy,
  SubscriptionHistoryAction action,
  PlanType beforePlan,
  PlanType afterPlan,
  /// 부여 기간(일). 무기한이거나 회수면 null
  Integer durationDays,
  /// 부여 후 만료일. 무기한이거나 회수면 null
  LocalDateTime afterExpiresAt,
  String reason
) {

  public static AdminSubscriptionHistoryLine from(SubscriptionHistory history) {
    return new AdminSubscriptionHistoryLine(
      history.getChangedAt(), history.getChangedBy(), history.getAction(),
      history.getBeforePlan(), history.getAfterPlan(),
      history.getDurationDays(), history.getAfterExpiresAt(), history.getReason());
  }
}
