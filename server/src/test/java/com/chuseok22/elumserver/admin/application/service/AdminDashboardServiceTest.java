package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.admin.application.dto.response.AdminDashboardSummary;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineStatusCounts;
import com.chuseok22.elumserver.admin.application.dto.response.SettingsOverview;
import com.chuseok22.elumserver.admin.application.dto.response.AdminDashboardSummary.TodayAiStats;
import java.util.List;
import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 대시보드 집계: 요금제 분포(Free = 전체 - 유효 Pro), 지금 적용 중 설정 요약 재사용, 60초 캐시
 * 캐시가 없으면 새로고침마다 집계 쿼리 7개 안팎이 나감
 */
class AdminDashboardServiceTest {

  private AdminMemberService memberService;
  private AdminRoutineService routineService;
  private AdminMonitoringService monitoringService;
  private SystemConfigOverviewService configOverviewService;
  private AdminAttentionService attentionService;
  private AdminStatsService statsService;
  private AtomicLong nowMilliseconds;
  private AdminDashboardService dashboardService;

  @BeforeEach
  void setUp() {
    memberService = mock(AdminMemberService.class);
    routineService = mock(AdminRoutineService.class);
    monitoringService = mock(AdminMonitoringService.class);
    configOverviewService = mock(SystemConfigOverviewService.class);
    attentionService = mock(AdminAttentionService.class);
    statsService = mock(AdminStatsService.class);
    nowMilliseconds = new AtomicLong(1_000_000L);

    when(memberService.count()).thenReturn(10L);
    when(memberService.countActiveWithinDays(7)).thenReturn(4L);
    when(memberService.countSuspended()).thenReturn(1L);
    when(memberService.countEffectivePro()).thenReturn(3L);
    when(routineService.getStatusCounts()).thenReturn(new AdminRoutineStatusCounts(5, 1, 2, 2));
    when(monitoringService.getTodayStatsSummary()).thenReturn(new TodayAiStats(0, 0, 0, 0));
    when(configOverviewService.buildRows()).thenReturn(List.of());
    when(configOverviewService.buildOverview(any(), any())).thenReturn(new SettingsOverview(2, List.of(), List.of()));

    dashboardService = new AdminDashboardService(
      memberService, routineService, monitoringService, configOverviewService, attentionService, statsService,
      nowMilliseconds::get);
  }

  @Test
  @DisplayName("요금제 분포: Pro 는 유효 Pro 수, Free 는 전체 회원에서 뺀 수")
  void distributesPlansByEffectivePro() {
    AdminDashboardSummary summary = dashboardService.summary();

    assertThat(summary.proMemberCount()).isEqualTo(3);
    assertThat(summary.freeMemberCount()).isEqualTo(7);
    assertThat(summary.memberCount()).isEqualTo(10);
  }

  @Test
  @DisplayName("Pro 수가 전체보다 많게 읽혀도 Free 는 음수가 되지 않는다")
  void freeCountNeverNegative() {
    when(memberService.countEffectivePro()).thenReturn(12L);

    assertThat(dashboardService.summary().freeMemberCount()).isZero();
  }

  @Test
  @DisplayName("지금 적용 중 설정 요약은 설정 화면 서비스의 결과를 그대로 쓴다")
  void reusesConfigOverview() {
    assertThat(dashboardService.summary().configOverview().differsFromDefaultCount()).isEqualTo(2);
  }

  @Test
  @DisplayName("60초 안에 다시 불러도 집계 쿼리는 1회만 나간다")
  void cachesFor60Seconds() {
    dashboardService.summary();
    nowMilliseconds.addAndGet(59_999L);
    dashboardService.summary();

    verify(memberService, times(1)).count();
    verify(memberService, times(1)).countEffectivePro();
    verify(routineService, times(1)).getStatusCounts();
    verify(monitoringService, times(1)).getTodayStatsSummary();
    verify(configOverviewService, times(1)).buildRows();
  }

  @Test
  @DisplayName("60초가 지나면 다시 집계한다")
  void reloadsAfter60Seconds() {
    dashboardService.summary();
    nowMilliseconds.addAndGet(60_000L);
    dashboardService.summary();

    verify(memberService, times(2)).count();
  }

  @Test
  @DisplayName("다시 집계하다 실패하면 이전 집계를 보여준다")
  void servesStaleSummaryWhenReloadFails() {
    AdminDashboardSummary first = dashboardService.summary();
    nowMilliseconds.addAndGet(60_000L);
    when(memberService.count()).thenThrow(new IllegalStateException("db down"));

    assertThat(dashboardService.summary()).isSameAs(first);
  }
}
