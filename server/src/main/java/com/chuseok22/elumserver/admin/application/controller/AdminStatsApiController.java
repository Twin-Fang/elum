package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.dto.response.AdminDashboardAttention;
import com.chuseok22.elumserver.admin.application.dto.response.AdminSidebarBadges;
import com.chuseok22.elumserver.admin.application.dto.response.AdminTrendChart;
import com.chuseok22.elumserver.admin.application.service.AdminDashboardService;
import com.chuseok22.elumserver.admin.application.service.AdminStatsService;
import com.chuseok22.elumserver.admin.application.stats.AdminAiUsageMetric;
import com.chuseok22.elumserver.admin.application.stats.AdminTrendRange;
import com.chuseok22.elumserver.common.application.exception.JsonErrorResponse;
import com.chuseok22.elumserver.talk.application.service.TalkAdminService;
import java.time.LocalDate;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 관리자 추이 그래프·사이드바 배지 JSON: 가입, 방문, AI 사용량, 배지 (기간: unit, from, to, days — 틀린 값은 기본값)
 * @LogMonitoring 없음: 배지가 화면마다 불려 로그만 채움 (AdminLogApiController 와 같음)
 */
@Slf4j
@RestController
@JsonErrorResponse
@RequiredArgsConstructor
public class AdminStatsApiController {

  /// days 파라미터 허용 범위 (1~366일)
  private static final int MAXIMUM_DEFAULT_DAYS = 366;

  private final AdminStatsService adminStatsService;
  private final AdminDashboardService adminDashboardService;
  private final TalkAdminService talkAdminService;

  @GetMapping("/admin/stats/api/signups")
  public AdminTrendChart signups(
    @RequestParam(name = "unit", required = false) String unit,
    @RequestParam(name = "from", required = false) String from,
    @RequestParam(name = "to", required = false) String to,
    @RequestParam(name = "days", required = false) Integer days
  ) {
    return adminStatsService.loadSignupTrend(rangeOf(unit, from, to, days));
  }

  @GetMapping("/admin/stats/api/visits")
  public AdminTrendChart visits(
    @RequestParam(name = "unit", required = false) String unit,
    @RequestParam(name = "from", required = false) String from,
    @RequestParam(name = "to", required = false) String to,
    @RequestParam(name = "days", required = false) Integer days
  ) {
    return adminStatsService.loadVisitTrend(rangeOf(unit, from, to, days));
  }

  /// metric: count(호출 수), cost(비용 원), failure(실패율 %)
  @GetMapping("/admin/stats/api/ai-usage")
  public AdminTrendChart aiUsage(
    @RequestParam(name = "unit", required = false) String unit,
    @RequestParam(name = "from", required = false) String from,
    @RequestParam(name = "to", required = false) String to,
    @RequestParam(name = "days", required = false) Integer days,
    @RequestParam(name = "metric", required = false) String metric
  ) {
    return adminStatsService.loadAiUsageTrend(rangeOf(unit, from, to, days), AdminAiUsageMetric.fromParameter(metric));
  }

  /// 사이드바 배지: 대시보드 집계(60초 캐시)를 쓰되, 이야기 신고 수는 가벼운 건수 조회라 바로 읽음
  @GetMapping("/admin/stats/api/badges")
  public AdminSidebarBadges badges() {
    AdminDashboardAttention attention = adminDashboardService.summary().attention();
    return new AdminSidebarBadges(
      attention.newFeedbackCount(), attention.pendingReviewRoutineCount(), attention.aiHealth().alertCount(),
      countUnresolvedTalkReportsSafely());
  }

  // 이야기 표 조회가 실패해도 다른 배지는 보여 줌 (실패 시 0)
  private long countUnresolvedTalkReportsSafely() {
    try {
      return talkAdminService.countUnresolvedReports();
    } catch (RuntimeException e) {
      log.warn("[admin badges] talk report count failed : badge shown as 0", e);
      return 0;
    }
  }

  private static AdminTrendRange rangeOf(String unit, String from, String to, Integer days) {
    int defaultDays = days == null || days < 1 || days > MAXIMUM_DEFAULT_DAYS ? AdminStatsService.DEFAULT_DAYS : days;
    return AdminTrendRange.of(unit, from, to, LocalDate.now(), defaultDays);
  }
}
