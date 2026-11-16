package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.admin.application.analytics.AdminAnalyticsPeriod;
import com.chuseok22.elumserver.admin.application.analytics.AdminAnalyticsSection;
import com.chuseok22.elumserver.admin.application.analytics.AdminAnalyticsSectionName;
import java.util.List;

/**
 * 사용 분석 화면 한 벌 (#1436, 칸별 독립 실패): 기간, 가입 단계, 가입 주차 리텐션, 마지막 활동 분포, 플랫폼, 분류 제안
 * 주별 추이는 그래프 부품이 JSON 으로 따로 부름
 */
public record AdminUsageAnalyticsView(
  AdminAnalyticsPeriod period,
  AdminAnalyticsSection<AdminUsageFunnel> funnel,
  AdminAnalyticsSection<List<AdminRetentionCohort>> retentionCohorts,
  AdminAnalyticsSection<List<AdminLabeledCount>> lastActivityDistribution,
  AdminAnalyticsSection<List<AdminLabeledCount>> platformMemberCounts,
  AdminAnalyticsSection<List<AdminAccountKindSuggestion>> suggestions
) {

  /// 주별 추이 그래프 실패 시 보일 에러 코드
  public String weeklyTrendErrorCode() {
    return AdminAnalyticsSectionName.TRENDS.errorCode();
  }
}
