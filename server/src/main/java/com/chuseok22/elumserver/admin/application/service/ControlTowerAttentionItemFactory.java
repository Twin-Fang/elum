package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.AdminDashboardAttention;
import com.chuseok22.elumserver.admin.application.dto.response.ControlTowerAttentionItem;
import com.chuseok22.elumserver.admin.application.dto.response.ControlTowerAttentionLevel;
import java.util.List;

/**
 * 대시보드 확인할 일 + 이야기 신고 수 > 관제소 항목 6개 (0건도 항상 포함, key 불변)
 * 수준 규칙: 0 > ok / 의견·검토 대기 > info / 신고·멈춘 예약·AI 이상 > warning / 비용 상한 100% critical, 80% warning
 */
final class ControlTowerAttentionItemFactory {

  // 관제소 표준 key 6개 (바꾸면 관제소 이력·알림 기준이 끊김)
  static final String KEY_FEEDBACK_NEW = "feedback.new";
  static final String KEY_REVIEW_PENDING = "review.pending";
  static final String KEY_JOB_STUCK = "job.stuck";
  static final String KEY_AI_ALERT = "ai.alert";
  static final String KEY_REPORT_UNRESOLVED = "report.unresolved";
  static final String KEY_BUDGET_DAILY = "budget.daily";

  // 항목별 관리자 화면 (대시보드 확인할 일 버튼과 같은 주소)
  private static final String FEEDBACK_NEW_PATH = "/admin/feedback?status=NEW";
  private static final String REVIEW_PENDING_PATH = "/admin/routines?status=PENDING_REVIEW";
  private static final String JOB_STUCK_PATH = "/admin/credits/jobs?status=RESERVED";
  private static final String AI_ALERT_PATH = "/admin/monitoring?success=false";
  private static final String REPORT_UNRESOLVED_PATH = "/admin/talk/reports";
  private static final String BUDGET_DAILY_PATH = "/admin/settings/ai#setting=AI_DAILY_BUDGET_USD";

  // 비용 상한 사용률 critical 기준 (%). warning 기준 80% 는 AdminDashboardAttention.isBudgetNearLimit
  private static final int BUDGET_CRITICAL_PERCENT = 100;
  private static final String BUDGET_UNIT = "USD";

  private ControlTowerAttentionItemFactory() {
  }

  /// adminBaseUrl: https 기준 주소면 절대 주소, 비면 상대 경로 (관제소가 source.admin_base_url 에 이어 붙임)
  static List<ControlTowerAttentionItem> itemsOf(
    AdminDashboardAttention attention, long unresolvedTalkReportCount, String adminBaseUrl
  ) {
    return List.of(
      countItem(KEY_FEEDBACK_NEW, "새 의견", attention.newFeedbackCount(), ControlTowerAttentionLevel.INFO,
        adminBaseUrl + FEEDBACK_NEW_PATH),
      countItem(KEY_REVIEW_PENDING, "검토 대기 일과", attention.pendingReviewRoutineCount(),
        ControlTowerAttentionLevel.INFO, adminBaseUrl + REVIEW_PENDING_PATH),
      countItem(KEY_JOB_STUCK, "멈춘 크레딧 예약", attention.stuckReservationCount(),
        ControlTowerAttentionLevel.WARNING, adminBaseUrl + JOB_STUCK_PATH),
      countItem(KEY_AI_ALERT, "AI 이상 제공자", attention.aiHealth().alertCount(),
        ControlTowerAttentionLevel.WARNING, adminBaseUrl + AI_ALERT_PATH),
      countItem(KEY_REPORT_UNRESOLVED, "처리 안 된 이야기 신고", unresolvedTalkReportCount,
        ControlTowerAttentionLevel.WARNING, adminBaseUrl + REPORT_UNRESOLVED_PATH),
      budgetItem(attention, adminBaseUrl + BUDGET_DAILY_PATH));
  }

  /// 0건 > ok, 1건 이상 > 항목별 수준
  private static ControlTowerAttentionItem countItem(
    String key, String label, long count, ControlTowerAttentionLevel levelWhenPresent, String adminUrl
  ) {
    ControlTowerAttentionLevel level = count > 0 ? levelWhenPresent : ControlTowerAttentionLevel.OK;
    return ControlTowerAttentionItem.count(key, label, count, level, adminUrl);
  }

  /// 오늘 AI 비용: 상한 꺼짐(budgetUsd -1) > limit 생략·ok, 켜짐 > 사용률로 수준 (대시보드와 같은 반올림)
  private static ControlTowerAttentionItem budgetItem(AdminDashboardAttention attention, String adminUrl) {
    Double limit = attention.isBudgetEnabled() ? attention.budgetUsd() : null;
    return ControlTowerAttentionItem.gauge(KEY_BUDGET_DAILY, "오늘 AI 비용", attention.spentUsd(), limit, BUDGET_UNIT,
      budgetLevelOf(attention), adminUrl);
  }

  static ControlTowerAttentionLevel budgetLevelOf(AdminDashboardAttention attention) {
    if (!attention.isBudgetEnabled()) {
      return ControlTowerAttentionLevel.OK;
    }
    if (attention.budgetUsedPercent() >= BUDGET_CRITICAL_PERCENT) {
      return ControlTowerAttentionLevel.CRITICAL;
    }
    return attention.isBudgetNearLimit() ? ControlTowerAttentionLevel.WARNING : ControlTowerAttentionLevel.OK;
  }
}
