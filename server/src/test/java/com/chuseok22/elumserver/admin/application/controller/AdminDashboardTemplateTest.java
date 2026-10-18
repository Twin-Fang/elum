package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.dto.response.AdminDashboardSummary;
import com.chuseok22.elumserver.admin.application.dto.response.AdminDashboardSummary.TodayAiStats;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineStatusCounts;
import com.chuseok22.elumserver.admin.application.dto.response.DashboardErrorsView;
import com.chuseok22.elumserver.admin.application.dto.response.SettingsOverview;
import com.chuseok22.elumserver.admin.application.dto.response.SettingsOverview.Highlight;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 대시보드·사이드바가 실제로 그려지는지: 요금제 분포, 숫자 카드 링크, 적용 중 설정 요약, 메뉴 그룹 3개
 * 식 하나가 틀리면 화면이 500 이라 렌더로 잡음
 */
class AdminDashboardTemplateTest {

  private final AdminTemplateRenderSupport renderer = new AdminTemplateRenderSupport();

  static AdminDashboardSummary summary() {
    return new AdminDashboardSummary(
      10, 4, 1, 3, 7,
      new AdminRoutineStatusCounts(5, 1, 2, 2),
      new TodayAiStats(4, 4, 1234, 0.12),
      new SettingsOverview(2, List.of(
        new Highlight("MAINTENANCE_MODE", "점검 모드", "켜짐", true, true),
        new Highlight("FREE_ADS_REMOVED", "Free 광고 제거", "꺼짐", false, false)), List.of()),
      LocalDateTime.of(2026, 10, 19, 9, 30)
    );
  }

  private String renderDashboard() {
    return renderer.render("admin/dashboard", Map.of(
      "summary", summary(),
      "recentErrors", new DashboardErrorsView(0, "10/19 09:00", List.of())));
  }

  @Test
  @DisplayName("요금제 분포는 Pro/Free 인원·비율을 그리고 각각 회원 목록 필터로 연결한다")
  void rendersPlanDistribution() {
    String html = renderDashboard();

    assertThat(html).contains("data-plan-distribution", "Pro <b>3</b>명", "Free <b>7</b>명",
      "width:30%", "/admin/members?plan=PRO", "/admin/members?plan=FREE");
  }

  @Test
  @DisplayName("숫자 카드는 회원, 일과, 모니터링 목록 링크를 가진다")
  void rendersCardLinks() {
    String html = renderDashboard();

    assertThat(html).contains("href=\"/admin/members\"", "href=\"/admin/routines\"", "href=\"/admin/monitoring\"",
      "/admin/members?status=SUSPENDED", "/admin/routines?status=PENDING_REVIEW");
  }

  @Test
  @DisplayName("지금 적용 중 설정 요약: 기본값과 다른 설정 수와 켜진 항목을 그린다")
  void rendersConfigSummary() {
    String html = renderDashboard();

    assertThat(html).contains("data-config-summary", "기본값과 다른 설정 2개", "점검 모드", "badge-success", "Free 광고 제거");
  }

  @Test
  @DisplayName("집계 시각을 보여준다")
  void rendersAggregatedAt() {
    assertThat(renderDashboard()).contains("2026-10-19 09:30");
  }

  @Test
  @DisplayName("사이드바는 운영, 콘텐츠, 시스템 순서로 그룹이 나뉘고 활성 메뉴만 active 다")
  void sidebarGroupsMenus() {
    String html = renderDashboard();

    int operations = html.indexOf("data-menu-group=\"operations\"");
    int contents = html.indexOf("data-menu-group=\"contents\"");
    int system = html.indexOf("data-menu-group=\"system\"");
    assertThat(operations).isPositive();
    assertThat(contents).isGreaterThan(operations);
    assertThat(system).isGreaterThan(contents);

    String operationsGroup = html.substring(operations, contents);
    assertThat(operationsGroup).contains("/admin/members", "/admin/routines", "/admin/credits", "/admin/feedback");
    String contentsGroup = html.substring(contents, system);
    assertThat(contentsGroup).contains("/admin/notices", "/admin/consents", "/admin/prompts");
    String systemGroup = html.substring(system);
    assertThat(systemGroup).contains("/admin/settings", "/admin/monitoring", "/admin/logs", "data-log-error-badge");
    assertThat(html).containsOnlyOnce("class=\"active\"");
  }
}
