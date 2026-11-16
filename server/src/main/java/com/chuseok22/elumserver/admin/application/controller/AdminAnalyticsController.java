package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.analytics.AdminAnalyticsPeriod;
import com.chuseok22.elumserver.admin.application.service.AdminUsageAnalyticsService;
import java.time.LocalDate;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;

/**
 * 사용 분석 화면 (#1436): 기간(weeks 4·8·12, 기본 8) + 모두 포함(includeAll=true) > 칸 5개, 주별 추이는 JSON 으로 따로
 */
@Controller
@RequiredArgsConstructor
public class AdminAnalyticsController {

  private final AdminUsageAnalyticsService adminUsageAnalyticsService;

  @GetMapping("/admin/analytics")
  public String analytics(
    @RequestParam(name = "weeks", required = false) String weeks,
    @RequestParam(name = "includeAll", required = false) String includeAll,
    Model model
  ) {
    AdminAnalyticsPeriod period = AdminAnalyticsPeriod.of(weeks, includeAll, LocalDate.now());
    model.addAttribute("analytics", adminUsageAnalyticsService.loadView(period, LocalDateTime.now()));
    model.addAttribute("retentionWeeksLater", AdminUsageAnalyticsService.RETENTION_WEEKS_LATER);
    return "admin/analytics";
  }
}
