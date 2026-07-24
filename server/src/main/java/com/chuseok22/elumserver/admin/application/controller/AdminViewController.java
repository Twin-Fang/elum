package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.service.AdminMemberService;
import com.chuseok22.elumserver.admin.application.service.AdminMonitoringService;
import com.chuseok22.elumserver.admin.application.service.AdminRoutineService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
@RequiredArgsConstructor
public class AdminViewController {

  private final AdminMemberService adminMemberService;
  private final AdminRoutineService adminRoutineService;
  private final AdminMonitoringService adminMonitoringService;

  @GetMapping("/admin/login")
  public String loginPage() {
    return "admin/login";
  }

  @GetMapping("/admin/dashboard")
  public String dashboard(Model model) {
    model.addAttribute("memberCount", adminMemberService.count());
    model.addAttribute("routineStats", adminRoutineService.getStatusCounts());
    model.addAttribute("todayAiStats", adminMonitoringService.getTodayStats());
    model.addAttribute("activeMemberCount", adminMemberService.countActiveWithinDays(7));
    model.addAttribute("suspendedMemberCount", adminMemberService.countSuspended());
    return "admin/dashboard";
  }
}
