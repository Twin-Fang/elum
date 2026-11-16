package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.admin.application.analytics.AdminAnalyticsSection;
import java.util.List;

/**
 * 대시보드 사용 칸 3개 (#1436, 칸별 독립 실패): 사용 요약 한 줄, 최근 가입 10명, 최근 활동 20줄
 */
public record AdminDashboardUsageOverview(
  AdminAnalyticsSection<AdminUsageHeadline> headline,
  AdminAnalyticsSection<List<AdminRecentSignup>> recentSignups,
  AdminAnalyticsSection<List<AdminRecentActivity>> recentActivities
) {
}
