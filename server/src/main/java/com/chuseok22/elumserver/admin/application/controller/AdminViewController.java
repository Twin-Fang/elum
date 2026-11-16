package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.service.AdminDashboardService;
import com.chuseok22.elumserver.admin.application.service.AdminDashboardUsageService;
import com.chuseok22.elumserver.admin.application.service.AdminLogOverviewService;
import java.time.Instant;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
@RequiredArgsConstructor
public class AdminViewController {

  private final AdminDashboardService adminDashboardService;
  private final AdminLogOverviewService adminLogOverviewService;
  private final AdminDashboardUsageService adminDashboardUsageService;

  @GetMapping("/admin/login")
  public String loginPage() {
    return "admin/login";
  }

  @GetMapping("/admin/dashboard")
  public String dashboard(Model model) {
    // 집계는 60초 캐시, 서버 오류 건수는 메모리 집계라 매번
    model.addAttribute("summary", adminDashboardService.summary());
    model.addAttribute("recentErrors", adminLogOverviewService.dashboardErrors(Instant.now()));
    // 사용 요약·최근 가입·최근 활동 (#1436, 칸별 60초 캐시·독립 실패)
    model.addAttribute("usageOverview", adminDashboardUsageService.loadOverview(LocalDateTime.now()));
    return "admin/dashboard";
  }

  // API 문서(Swagger)를 관리자 화면 안에 iframe 으로 보여준다. /admin/** 체인이 로그인한 관리자에게만 연다.
  @GetMapping("/admin/api-docs")
  public String apiDocs() {
    return "admin/api-docs";
  }
}
