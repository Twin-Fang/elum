package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.service.AdminDashboardService;
import com.chuseok22.elumserver.admin.application.service.AdminLogOverviewService;
import java.time.Instant;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
@RequiredArgsConstructor
public class AdminViewController {

  private final AdminDashboardService adminDashboardService;
  private final AdminLogOverviewService adminLogOverviewService;

  @GetMapping("/admin/login")
  public String loginPage() {
    return "admin/login";
  }

  @GetMapping("/admin/dashboard")
  public String dashboard(Model model) {
    // 집계는 60초 캐시, 서버 오류 건수는 메모리 집계라 매번
    model.addAttribute("summary", adminDashboardService.summary());
    model.addAttribute("recentErrors", adminLogOverviewService.dashboardErrors(Instant.now()));
    return "admin/dashboard";
  }

  // API 문서(Swagger)를 관리자 화면 안에 iframe 으로 보여준다. /admin/** 체인이 로그인한 관리자에게만 연다.
  @GetMapping("/admin/api-docs")
  public String apiDocs() {
    return "admin/api-docs";
  }
}
