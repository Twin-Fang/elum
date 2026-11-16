package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.analytics.AdminAnalyticsPeriod;
import com.chuseok22.elumserver.admin.application.analytics.AdminAnalyticsSection;
import com.chuseok22.elumserver.admin.application.dto.response.AdminTrendChart;
import com.chuseok22.elumserver.admin.application.service.AdminUsageAnalyticsService;
import com.chuseok22.elumserver.common.application.exception.JsonErrorResponse;
import java.time.LocalDate;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 사용 분석 주별 추이 JSON (#1436): 추이 그래프 부품(admin-charts.js)이 부름. 실패하면 500 + 에러 코드 (그래프 칸만 안내)
 * @LogMonitoring 없음: 다른 관리자 추이 JSON(AdminStatsApiController)과 같음
 */
@RestController
@JsonErrorResponse
@RequiredArgsConstructor
public class AdminAnalyticsApiController {

  private final AdminUsageAnalyticsService adminUsageAnalyticsService;

  @GetMapping("/admin/analytics/api/weekly-usage")
  public ResponseEntity<Object> weeklyUsage(
    @RequestParam(name = "weeks", required = false) String weeks,
    @RequestParam(name = "includeAll", required = false) String includeAll
  ) {
    AdminAnalyticsSection<AdminTrendChart> trend = adminUsageAnalyticsService.loadWeeklyTrend(
      AdminAnalyticsPeriod.of(weeks, includeAll, LocalDate.now()));
    if (trend.isLoadFailed()) {
      return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(new LoadFailedBody(trend.errorCode()));
    }
    return ResponseEntity.ok(trend.value());
  }

  /** 실패 응답 본문: 에러 코드만 */
  record LoadFailedBody(String errorCode) {
  }
}
