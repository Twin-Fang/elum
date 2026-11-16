package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.analytics.AdminAnalyticsPeriod;
import com.chuseok22.elumserver.admin.application.analytics.AdminAnalyticsSection;
import com.chuseok22.elumserver.admin.application.analytics.AdminAnalyticsSectionName;
import com.chuseok22.elumserver.admin.application.dto.response.AdminAccountKindSuggestion;
import com.chuseok22.elumserver.admin.application.dto.response.AdminDashboardUsageOverview;
import com.chuseok22.elumserver.admin.application.dto.response.AdminLabeledCount;
import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberDetailResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRecentActivity;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRecentSignup;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRetentionCohort;
import com.chuseok22.elumserver.admin.application.dto.response.AdminSubscriptionSummary;
import com.chuseok22.elumserver.admin.application.dto.response.AdminUsageAnalyticsView;
import com.chuseok22.elumserver.admin.application.dto.response.AdminUsageHeadline;
import com.chuseok22.elumserver.admin.application.dto.response.DashboardErrorsView;
import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminMemberList;
import com.chuseok22.elumserver.admin.application.service.AdminUsageAnalyticsService;
import com.chuseok22.elumserver.member.core.MemberAccountKind;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;

/**
 * 사용 분석 화면·대시보드 사용 칸·회원 계정 종류가 실제로 그려지는지 (#1436)
 * 식 하나가 틀리면 화면 전체가 500 이라 렌더로 잡음. 칸 하나 실패가 다른 칸을 가리지 않는지도 봄
 */
class AdminUsageAnalyticsTemplateTest {

  private static final LocalDate TODAY = LocalDate.of(2026, 11, 16);
  private static final LocalDateTime JOINED_AT = LocalDateTime.of(2026, 11, 10, 9, 30);

  private final AdminTemplateRenderSupport renderer = new AdminTemplateRenderSupport();

  @Test
  @DisplayName("사용 분석: 기간 버튼·가입 단계·리텐션 칸(비율, -, 기록 전)·주별 추이 주소·분포·분류 제안 버튼이 그려진다")
  void analyticsRendersAllSections() {
    String html = renderAnalytics(loadedView(AdminAnalyticsPeriod.of("4", "true", TODAY)));

    assertThat(html).contains("/admin/analytics?weeks=8&amp;includeAll=true", "모두 포함해서 보는 중")
      .doesNotContain("data-account-kind-excluded-note");
    assertThat(html).contains("일과 만듦", "29명 (56%)", "이전 단계의 56%", "width:56%");
    assertThat(html).contains("11/10 주", "33% (1명)", "기록 전", ">-<");
    assertThat(html).contains("/admin/analytics/api/weekly-usage?weeks=4&amp;includeAll=true",
      "data-error-code=\"E-ADMIN-ANALYTICS-TRENDS\"");
    assertThat(html).contains("30일 넘음", "iOS");
    assertThat(html).contains("/admin/analytics/suggestions/m-review/classify", "name=\"accountKind\" value=\"STORE_REVIEW\"",
      "/admin/analytics/suggestions/m-review/dismiss", "일반 맞음");
    assertThat(html).contains("data-menu-group=\"operations\"").containsOnlyOnce("class=\"active\"");
  }

  @Test
  @DisplayName("사용 분석: 칸 하나가 실패하면 그 칸만 에러 코드, 빈 칸은 빈 상태 문구 (화면은 그대로)")
  void analyticsShowsSectionFailureAndEmptyStates() {
    AdminUsageAnalyticsView view = new AdminUsageAnalyticsView(
      AdminAnalyticsPeriod.of(null, null, TODAY),
      AdminAnalyticsSection.failed(AdminAnalyticsSectionName.FUNNEL.errorCode()),
      AdminAnalyticsSection.loaded(List.of()),
      AdminAnalyticsSection.loaded(AdminLabeledCount.withPercents(List.of("1일 안"), List.of(0L))),
      AdminAnalyticsSection.failed(AdminAnalyticsSectionName.PLATFORM.errorCode()),
      AdminAnalyticsSection.loaded(List.of()));

    String html = renderAnalytics(view);

    assertThat(html).contains("불러오지 못했어요 (E-ADMIN-ANALYTICS-FUNNEL)", "불러오지 못했어요 (E-ADMIN-ANALYTICS-PLATFORM)");
    assertThat(html).contains("이 기간에 가입한 사람이 없어요", "회원이 없어요", "제안할 계정이 없어요");
    assertThat(html).contains("data-account-kind-excluded-note", "/admin/analytics?weeks=8&amp;includeAll=true");
  }

  @Test
  @DisplayName("대시보드: 사용 요약 링크·최근 가입(종류 배지)·최근 활동 줄과 일반 계정만 안내가 그려진다")
  void dashboardRendersUsageOverview() {
    AdminDashboardUsageOverview overview = new AdminDashboardUsageOverview(
      AdminAnalyticsSection.loaded(new AdminUsageHeadline(8, 21, 14, 37)),
      AdminAnalyticsSection.loaded(List.of(
        new AdminRecentSignup("m-new", "하늘보호자", JOINED_AT, "애플", 2, true, JOINED_AT, "내부", "info"))),
      AdminAnalyticsSection.loaded(List.of(
        new AdminRecentActivity(JOINED_AT, "m-new", "하늘보호자", "카드 3장 체크"))));

    String html = renderDashboard(overview);

    assertThat(html).contains("이번 주 쓴 사람 <b>8명</b>", "7일 리텐션 <b>21%</b>", "이번 주 카드 체크 <b>37장</b>",
      "href=\"/admin/analytics\"");
    assertThat(html).contains("/admin/members/m-new", "badge-info", "내부", "연결", "카드 3장 체크");
    assertThat(html).contains("내부·테스트·심사 계정 제외");
  }

  @Test
  @DisplayName("대시보드: 최근 활동 칸이 실패해도 요약·최근 가입은 그려지고, 사용 칸이 없어도 대시보드는 열린다")
  void dashboardKeepsOtherSectionsWhenOneFails() {
    AdminDashboardUsageOverview overview = new AdminDashboardUsageOverview(
      AdminAnalyticsSection.loaded(new AdminUsageHeadline(0, null, 0, 0)),
      AdminAnalyticsSection.loaded(List.of()),
      AdminAnalyticsSection.failed(AdminAnalyticsSectionName.RECENT_ACTIVITY.errorCode()));

    assertThat(renderDashboard(overview)).contains("7일 리텐션 <b>-</b>", "아직 가입한 사람이 없어요",
      "불러오지 못했어요 (E-ADMIN-ANALYTICS-RECENT-ACTIVITY)");
    assertThat(renderDashboard(null)).contains("지금 접속 중").doesNotContain("data-dashboard-usage");
  }

  @Test
  @DisplayName("회원 상세·목록: 계정 종류 선택(지금 값 선택됨)·저장 주소, 목록 배지와 계정 종류 필터가 그려진다")
  void memberPagesRenderAccountKind() {
    Member member = new Member();
    member.setId("m1");
    member.setUsername("parent1");
    member.setStatus(MemberStatus.ACTIVE);
    member.setAccountKind(MemberAccountKind.STORE_REVIEW);
    member.setAccountKindChangedAt(JOINED_AT);
    member.setAccountKindChangedBy("admin1");

    String detail = renderer.render("admin/member-detail", Map.of("member",
      AdminMemberDetailResponse.of(member, null, List.of(), null, List.of(), AdminSubscriptionSummary.none(), List.of(), null)));
    assertThat(detail).contains("data-member-account-kind", "/admin/members/m1/account-kind",
      "value=\"STORE_REVIEW\" selected=\"selected\"", "badge-ghost", "· admin1");

    AdminListQuery query = AdminListQuery.of(null, Map.of(), null, null, AdminMemberList.DEFINITION);
    Map<String, Object> model = new HashMap<>();
    model.put("members", new PageImpl<>(List.of(), PageRequest.of(0, 20), 1));
    model.put("definition", AdminMemberList.DEFINITION);
    model.put("query", query);
    model.put("rows", List.of(AdminMemberList.toRow(
      AdminMemberResponse.of(member, null, 0, null, null, null, null), new AdminDateFormatter())));
    model.put("pagerBaseUrl", "/admin/members");
    String list = renderer.render("admin/members", model);
    assertThat(list).contains("계정 종류", "accountKind=STORE_REVIEW", "badge-ghost", "스토어 심사");
  }

  private AdminUsageAnalyticsView loadedView(AdminAnalyticsPeriod period) {
    AdminRetentionCohort cohort = new AdminRetentionCohort("11/10 주", 3, List.of(
      AdminRetentionCohort.Cell.of(LocalDate.of(2026, 10, 27), 1, 1, 3, TODAY, LocalDate.of(2026, 10, 21)),
      AdminRetentionCohort.Cell.of(LocalDate.of(2026, 10, 6), 2, 0, 3, TODAY, LocalDate.of(2026, 10, 21)),
      AdminRetentionCohort.Cell.of(LocalDate.of(2026, 11, 10), 4, 0, 3, TODAY, LocalDate.of(2026, 10, 21))));
    return new AdminUsageAnalyticsView(
      period,
      AdminAnalyticsSection.loaded(AdminUsageAnalyticsService.toFunnel(List.of(52L, 29L, 11L, 6L, 0L))),
      AdminAnalyticsSection.loaded(List.of(cohort)),
      AdminAnalyticsSection.loaded(AdminLabeledCount.withPercents(
        List.of("1일 안", "30일 넘음"), List.of(3L, 9L))),
      AdminAnalyticsSection.loaded(AdminLabeledCount.withPercents(List.of("iOS", "Android"), List.of(5L, 2L))),
      AdminAnalyticsSection.loaded(List.of(new AdminAccountKindSuggestion(
        "m-review", "심사계정", JOINED_AT, MemberAccountKind.STORE_REVIEW, "Apple 이메일 가리기"))));
  }

  private String renderAnalytics(AdminUsageAnalyticsView view) {
    return renderer.render("admin/analytics", Map.of(
      "analytics", view, "retentionWeeksLater", AdminUsageAnalyticsService.RETENTION_WEEKS_LATER));
  }

  private String renderDashboard(AdminDashboardUsageOverview overview) {
    Map<String, Object> model = new HashMap<>();
    model.put("summary", AdminDashboardTemplateTest.summary());
    model.put("recentErrors", new DashboardErrorsView(0, "10/19 09:00", List.of()));
    if (overview != null) {
      model.put("usageOverview", overview);
    }
    return renderer.render("admin/dashboard", model);
  }
}
