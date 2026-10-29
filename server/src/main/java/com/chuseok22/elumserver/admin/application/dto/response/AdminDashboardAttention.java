package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.ai.application.dto.response.AiHealthSnapshot;

/**
 * 대시보드 확인할 일 5종: 새 의견, 검토 대기 일과, AI 이상, 멈춘 예약, 오늘 비용 상한
 * budgetUsd: -1 이면 상한 꺼짐 / spentUsd: 오늘 추정 비용
 */
public record AdminDashboardAttention(
  long newFeedbackCount,
  long pendingReviewRoutineCount,
  long stuckReservationCount,
  AiHealthSnapshot aiHealth,
  double budgetUsd,
  double spentUsd
) {

  /// 상한 사용률 경고 기준 (%)
  static final int BUDGET_WARNING_PERCENT = 80;

  public boolean isBudgetEnabled() {
    return budgetUsd >= 0;
  }

  /** 상한 사용률(%) — 꺼져 있으면 0, 상한 0 이면 100 */
  public int budgetUsedPercent() {
    if (!isBudgetEnabled()) {
      return 0;
    }
    if (budgetUsd == 0) {
      return 100;
    }
    return (int) Math.min(999, Math.round(spentUsd * 100 / budgetUsd));
  }

  /** 상한 80% 이상이면 확인할 일 */
  public boolean isBudgetNearLimit() {
    return isBudgetEnabled() && budgetUsedPercent() >= BUDGET_WARNING_PERCENT;
  }

  public boolean hasAnyItem() {
    return newFeedbackCount > 0 || pendingReviewRoutineCount > 0 || stuckReservationCount > 0
      || aiHealth.alertCount() > 0 || isBudgetNearLimit();
  }
}
