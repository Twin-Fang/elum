package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.service.AdminPushService;
import com.chuseok22.elumserver.notification.core.AdminMessageRoute;
import com.chuseok22.elumserver.notification.infrastructure.entity.AdminMessage;
import jakarta.servlet.http.HttpSession;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

/// 알림 보내기 화면 (#1273): 받는 사람·문구 입력 (미리 계산·보내기는 AdminPushApiController JSON)
@Controller
@RequiredArgsConstructor
public class AdminPushController {

  static final String PAGE_PATH = "/admin/push";

  private final AdminPushService adminPushService;

  @GetMapping(PAGE_PATH)
  public String page(HttpSession session, Model model) {
    model.addAttribute("testMemberId", session.getAttribute(AdminPushApiController.TEST_MEMBER_SESSION_KEY));
    model.addAttribute("maximumRecipientCount", AdminPushService.MAXIMUM_RECIPIENT_COUNT);
    model.addAttribute("titleMaxLength", AdminMessage.TITLE_MAX_LENGTH);
    model.addAttribute("bodyMaxLength", AdminMessage.BODY_MAX_LENGTH);
    model.addAttribute("routeOptions", List.of(AdminMessageRoute.values()));
    model.addAttribute("isQuietHours", adminPushService.isQuietHoursNow());
    return "admin/push";
  }
}
