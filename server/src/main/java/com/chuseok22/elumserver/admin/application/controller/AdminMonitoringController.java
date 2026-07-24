package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.service.AdminMonitoringService;
import com.chuseok22.elumserver.ai.core.AiCallType;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;

@Controller
@RequiredArgsConstructor
public class AdminMonitoringController {

  private final AdminMonitoringService adminMonitoringService;

  @GetMapping("/admin/monitoring")
  public String monitoring(
    @RequestParam(name = "callType", required = false) AiCallType callType,
    @RequestParam(name = "success", required = false) Boolean success,
    @RequestParam(name = "page", defaultValue = "0") int page,
    Model model
  ) {
    model.addAttribute("todayStats", adminMonitoringService.getTodayStats());
    model.addAttribute("totalStats", adminMonitoringService.getTotalStats());
    model.addAttribute("calls", adminMonitoringService.getCalls(callType, success, page));
    model.addAttribute("callTypes", AiCallType.values());
    model.addAttribute("selectedCallType", callType);
    model.addAttribute("selectedSuccess", success);
    return "admin/monitoring";
  }
}
