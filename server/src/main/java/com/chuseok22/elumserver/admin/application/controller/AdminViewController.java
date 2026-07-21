package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.service.AdminMemberService;
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

  @GetMapping("/admin/login")
  public String loginPage() {
    return "admin/login";
  }

  @GetMapping("/admin/dashboard")
  public String dashboard(Model model) {
    model.addAttribute("memberCount", adminMemberService.count());
    model.addAttribute("routineStats", adminRoutineService.getStatusCounts());
    return "admin/dashboard";
  }
}
