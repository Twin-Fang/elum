package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.analytics.AdminAnalyticsPeriod;
import com.chuseok22.elumserver.admin.application.analytics.AdminAnalyticsSectionLoader;
import com.chuseok22.elumserver.admin.application.analytics.AdminAnalyticsSectionName;
import com.chuseok22.elumserver.admin.application.analytics.AdminRecentActivityKind;
import com.chuseok22.elumserver.admin.application.dto.response.AdminDashboardUsageOverview;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRecentActivity;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRecentSignup;
import com.chuseok22.elumserver.admin.application.dto.response.AdminUsageHeadline;
import com.chuseok22.elumserver.admin.application.format.AdminAccountKindBadges;
import com.chuseok22.elumserver.admin.application.format.AdminMemberDisplayNames;
import com.chuseok22.elumserver.admin.application.list.AdminMemberList;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsQueries;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsRows.HeadlineCounts;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsRows.RecentActivityRow;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsRows.RecentSignupRow;
import com.chuseok22.elumserver.auth.infrastructure.oauth.OAuthProvider;
import com.chuseok22.elumserver.member.core.MemberAccountKind;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.Objects;
import java.util.function.LongSupplier;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/**
 * 대시보드 사용 칸 3개 (#1436): 사용 요약 한 줄(일반 계정만), 최근 가입 10명(계정 종류 배지), 최근 활동 20줄(일반 계정만)
 * 칸마다 60초 캐시·독립 실패 (AdminAnalyticsSectionLoader)
 */
@Service
public class AdminDashboardUsageService {

  /// 최근 가입 줄 수 (10명), 최근 활동 줄 수 (20줄)와 살펴볼 기간 (30일)
  static final int RECENT_SIGNUP_LIMIT = 10;
  static final int RECENT_ACTIVITY_LIMIT = 20;
  static final int RECENT_ACTIVITY_WITHIN_DAYS = 30;
  /// 7일 리텐션 대상: 최근 28일(4주) 가입 중 가입 뒤 7일이 다 지난 사람
  static final int RETENTION_COHORT_DAYS = 28;
  static final int RETENTION_WINDOW_DAYS = 7;
  private static final String LOGIN_METHOD_DELIMITER = ",";
  private static final String LOGIN_METHOD_TEXT_DELIMITER = ", ";
  private static final String BLANK_TEXT = "-";

  private final AdminUsageAnalyticsQueries usageAnalyticsQueries;
  private final AdminAnalyticsSectionLoader sectionLoader;

  @Autowired
  public AdminDashboardUsageService(AdminUsageAnalyticsQueries usageAnalyticsQueries) {
    this(usageAnalyticsQueries, System::currentTimeMillis);
  }

  /// 시험에서 캐시 시계를 바꿔 끼우려고 열어 둔 생성자
  AdminDashboardUsageService(AdminUsageAnalyticsQueries usageAnalyticsQueries, LongSupplier currentMilliseconds) {
    this.usageAnalyticsQueries = usageAnalyticsQueries;
    this.sectionLoader = new AdminAnalyticsSectionLoader(currentMilliseconds);
  }

  /** 대시보드 사용 칸 3개 (각각 실패해도 나머지는 보임) */
  public AdminDashboardUsageOverview loadOverview(LocalDateTime now) {
    LocalDate today = now.toLocalDate();
    return new AdminDashboardUsageOverview(
      sectionLoader.loadCached(AdminAnalyticsSectionName.HEADLINE, today.toString(), () -> loadHeadline(today)),
      sectionLoader.loadCached(AdminAnalyticsSectionName.RECENT_SIGNUPS, "", this::loadRecentSignups),
      sectionLoader.loadCached(AdminAnalyticsSectionName.RECENT_ACTIVITY, "", () -> loadRecentActivities(now)));
  }

  // 이번 주(월요일부터) 활성·카드 체크, 7일 리텐션 [오늘-28일, 오늘-7일) 가입자
  private AdminUsageHeadline loadHeadline(LocalDate today) {
    HeadlineCounts counts = usageAnalyticsQueries.countHeadline(AdminAnalyticsPeriod.weekStartOf(today),
      today.minusDays(RETENTION_COHORT_DAYS).atStartOfDay(), today.minusDays(RETENTION_WINDOW_DAYS).atStartOfDay());
    Integer retentionPercent = counts.retentionCohortSize() == 0
      ? null
      : (int) Math.round(counts.retainedCount() * 100.0 / counts.retentionCohortSize());
    return new AdminUsageHeadline(counts.weeklyActiveCount(), retentionPercent, counts.retentionCohortSize(),
      counts.cardCheckCount());
  }

  private List<AdminRecentSignup> loadRecentSignups() {
    return usageAnalyticsQueries.findRecentSignups(RECENT_SIGNUP_LIMIT).stream()
      .map(AdminDashboardUsageService::toRecentSignup)
      .toList();
  }

  // 모르는 활동 종류는 건너뜀 (쿼리와 enum 이 어긋나도 칸은 그대로)
  private List<AdminRecentActivity> loadRecentActivities(LocalDateTime now) {
    return usageAnalyticsQueries.findRecentActivities(now.minusDays(RECENT_ACTIVITY_WITHIN_DAYS), RECENT_ACTIVITY_LIMIT)
      .stream()
      .map(AdminDashboardUsageService::toRecentActivity)
      .filter(Objects::nonNull)
      .toList();
  }

  private static AdminRecentSignup toRecentSignup(RecentSignupRow row) {
    MemberAccountKind accountKind = MemberAccountKind.fromParameterOrNull(row.accountKind());
    return new AdminRecentSignup(row.memberId(),
      AdminMemberDisplayNames.of(row.nickname(), row.memberId()), row.createdAt(),
      loginMethodTextOf(row.loginProviders()), row.routineCount(), row.hasLinkedDevice(), row.lastActivityAt(),
      accountKind == null ? BLANK_TEXT : accountKind.getLabel(), AdminAccountKindBadges.toneOf(accountKind));
  }

  private static AdminRecentActivity toRecentActivity(RecentActivityRow row) {
    AdminRecentActivityKind kind = AdminRecentActivityKind.fromQueryValueOrNull(row.activityKind());
    if (kind == null) {
      return null;
    }
    return new AdminRecentActivity(row.occurredAt(), row.memberId(),
      AdminMemberDisplayNames.of(row.nickname(), row.memberId()), kind.describe(row.itemCount()));
  }

  // 제공자 이름 목록(APPLE,GOOGLE) > 화면 이름 (모르는 값은 건너뜀, 없으면 "-")
  static String loginMethodTextOf(String loginProviders) {
    if (loginProviders == null || loginProviders.isBlank()) {
      return BLANK_TEXT;
    }
    String text = Arrays.stream(loginProviders.split(LOGIN_METHOD_DELIMITER))
      .map(String::trim)
      .flatMap(name -> Arrays.stream(OAuthProvider.values()).filter(provider -> provider.name().equals(name)))
      .map(AdminMemberList::providerLabel)
      .collect(Collectors.joining(LOGIN_METHOD_TEXT_DELIMITER));
    return text.isEmpty() ? BLANK_TEXT : text;
  }
}
