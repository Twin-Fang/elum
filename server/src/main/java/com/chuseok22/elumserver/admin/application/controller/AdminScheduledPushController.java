package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.dto.request.AdminPushRequest;
import com.chuseok22.elumserver.admin.application.service.AdminScheduledPushService;
import com.chuseok22.elumserver.admin.application.service.AdminScheduledPushService.ScheduleResult;
import com.chuseok22.elumserver.notification.core.AdminMessageRoute;
import com.chuseok22.elumserver.notification.core.NotificationQuietHours;
import com.chuseok22.elumserver.notification.infrastructure.entity.AdminMessage;
import java.util.Arrays;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

/// 예약 발송 화면 (#1275): 만들기(받는 사람·문구·시각), 최근 50건 목록, 기다림 취소
@Controller
@RequiredArgsConstructor
public class AdminScheduledPushController {

  static final String PAGE_PATH = "/admin/push/scheduled";
  private static final String REDIRECT_TO_PAGE = "redirect:" + PAGE_PATH;
  private static final String MEMBER_ID_DELIMITER = ",";

  private final AdminScheduledPushService adminScheduledPushService;

  @GetMapping(PAGE_PATH)
  public String page(Model model) {
    model.addAttribute("scheduledPushes", adminScheduledPushService.findRecent());
    model.addAttribute("routeOptions", List.of(AdminMessageRoute.values()));
    model.addAttribute("titleMaxLength", AdminMessage.TITLE_MAX_LENGTH);
    model.addAttribute("bodyMaxLength", AdminMessage.BODY_MAX_LENGTH);
    model.addAttribute("quietHoursStart", NotificationQuietHours.START);
    model.addAttribute("quietHoursEnd", NotificationQuietHours.END);
    return "admin/push-scheduled";
  }

  /// 만들기: memberIdsCsv 는 회원 고르기 위젯의 숨은 입력(name=value, 쉼표 목록)
  @PostMapping(PAGE_PATH)
  public String create(@RequestParam(name = "targetMode", required = false) String targetMode,
    @RequestParam(name = "value", required = false) String memberIdsCsv,
    @RequestParam(name = "joinedOnOrBefore", required = false) String joinedOnOrBefore,
    @RequestParam(name = "minimumAiCallCount", required = false) Integer minimumAiCallCount,
    @RequestParam(name = "title", required = false) String title,
    @RequestParam(name = "body", required = false) String body,
    @RequestParam(name = "route", required = false) String route,
    @RequestParam(name = "scheduledAt", required = false) String scheduledAt,
    Authentication authentication, RedirectAttributes redirectAttributes) {
    AdminPushRequest request = new AdminPushRequest(targetMode, memberIdsOf(memberIdsCsv), joinedOnOrBefore,
      minimumAiCallCount, title, body, route, null);
    ScheduleResult result = adminScheduledPushService.create(request, scheduledAt,
      authentication == null ? null : authentication.getName());
    if (result.isCreated()) {
      redirectAttributes.addFlashAttribute("message", "알림을 예약했어요.");
    } else {
      redirectAttributes.addFlashAttribute("errorMessage", result.rejectionMessage());
    }
    return REDIRECT_TO_PAGE;
  }

  @PostMapping(PAGE_PATH + "/{id}/cancel")
  public String cancel(@PathVariable("id") String id, RedirectAttributes redirectAttributes) {
    if (adminScheduledPushService.cancel(id)) {
      redirectAttributes.addFlashAttribute("message", "예약을 취소했어요.");
    } else {
      redirectAttributes.addFlashAttribute("errorMessage", "기다리는 예약만 취소할 수 있어요 (이미 보냈거나 보내는 중)");
    }
    return REDIRECT_TO_PAGE;
  }

  private static List<String> memberIdsOf(String memberIdsCsv) {
    if (memberIdsCsv == null || memberIdsCsv.isBlank()) {
      return List.of();
    }
    return Arrays.stream(memberIdsCsv.split(MEMBER_ID_DELIMITER)).map(String::strip)
      .filter(memberId -> !memberId.isEmpty()).toList();
  }
}
