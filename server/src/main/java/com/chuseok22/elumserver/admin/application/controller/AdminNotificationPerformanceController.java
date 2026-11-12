package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.notification.application.service.NotificationPerformanceService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

/// 알림 성과 화면 (#1275): 종류별 7일·30일 받은 사람·도착·열림·열림률, 끈 사람 수
@Controller
@RequiredArgsConstructor
public class AdminNotificationPerformanceController {

  static final String PAGE_PATH = "/admin/push/performance";

  private final NotificationPerformanceService notificationPerformanceService;

  @GetMapping(PAGE_PATH)
  public String page(Model model) {
    model.addAttribute("rows", notificationPerformanceService.summarize());
    model.addAttribute("allOffCount", notificationPerformanceService.countAllOff());
    model.addAttribute("shortPeriodDays", NotificationPerformanceService.SHORT_PERIOD_DAYS);
    model.addAttribute("longPeriodDays", NotificationPerformanceService.LONG_PERIOD_DAYS);
    return "admin/push-performance";
  }
}
