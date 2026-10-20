package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.admin.application.dto.response.AdminDashboardAttention;
import com.chuseok22.elumserver.admin.application.dto.response.AdminDashboardSummary;
import com.chuseok22.elumserver.admin.application.dto.response.AdminSidebarBadges;
import com.chuseok22.elumserver.admin.application.service.AdminDashboardService;
import com.chuseok22.elumserver.admin.application.service.AdminStatsService;
import com.chuseok22.elumserver.ai.application.dto.response.AiHealthSnapshot;
import com.chuseok22.elumserver.talk.application.service.TalkAdminService;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class AdminTalkSidebarBadgeTest {

  @Test
  @DisplayName("사이드바 배지 응답에 처리하지 않은 이야기 신고 수가 대시보드 집계와 함께 실린다")
  void badges_includeUnresolvedTalkReportCount() {
    AdminDashboardService dashboardService = mock(AdminDashboardService.class);
    TalkAdminService talkAdminService = mock(TalkAdminService.class);
    AdminDashboardSummary summary = mock(AdminDashboardSummary.class);
    when(summary.attention()).thenReturn(new AdminDashboardAttention(
      2, 1, 0, new AiHealthSnapshot(List.of(), List.of()), -1, 0));
    when(dashboardService.summary()).thenReturn(summary);
    when(talkAdminService.countUnresolvedReports()).thenReturn(6L);
    AdminStatsApiController controller =
      new AdminStatsApiController(mock(AdminStatsService.class), dashboardService, talkAdminService);

    AdminSidebarBadges badges = controller.badges();

    assertThat(badges.unresolvedTalkReportCount()).isEqualTo(6L);
    assertThat(badges.newFeedbackCount()).isEqualTo(2L);
    assertThat(badges.pendingReviewRoutineCount()).isEqualTo(1L);
  }
}
