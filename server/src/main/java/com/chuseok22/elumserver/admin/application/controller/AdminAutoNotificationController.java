package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.service.AdminAuditService;
import com.chuseok22.elumserver.admin.core.AdminAuditAction;
import com.chuseok22.elumserver.notification.application.service.AutoNotificationRuleService;
import com.chuseok22.elumserver.notification.application.service.AutoNotificationRuleService.RuleUpdate;
import com.chuseok22.elumserver.notification.application.service.AutoNotificationRuleService.RuleUpdateResult;
import com.chuseok22.elumserver.notification.application.service.AutoNotificationTemplate;
import com.chuseok22.elumserver.notification.core.AdminMessageRoute;
import com.chuseok22.elumserver.notification.core.AutoNotificationType;
import com.chuseok22.elumserver.notification.infrastructure.entity.AdminMessage;
import java.util.List;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

/// 자동 알림 관리 화면 (#1275): 종류별 켜기·문구·시각·간격 저장 (저장마다 관리자 기록)
@Controller
@RequiredArgsConstructor
public class AdminAutoNotificationController {

  static final String PAGE_PATH = "/admin/push/auto";
  private static final String REDIRECT_TO_PAGE = "redirect:" + PAGE_PATH;

  private final AutoNotificationRuleService autoNotificationRuleService;
  private final AdminAuditService adminAuditService;

  @GetMapping(PAGE_PATH)
  public String page(Model model) {
    model.addAttribute("rules", autoNotificationRuleService.findAll());
    model.addAttribute("routeOptions", List.of(AdminMessageRoute.values()));
    model.addAttribute("templateVariables", AutoNotificationTemplate.VARIABLES);
    model.addAttribute("titleMaxLength", AdminMessage.TITLE_MAX_LENGTH);
    model.addAttribute("bodyMaxLength", AdminMessage.BODY_MAX_LENGTH);
    model.addAttribute("minimumIntervalDays", AutoNotificationRuleService.MINIMUM_INTERVAL_DAYS);
    model.addAttribute("maximumIntervalDays", AutoNotificationRuleService.MAXIMUM_INTERVAL_DAYS);
    return "admin/push-auto";
  }

  /// 저장: 검사 거절은 사유 문구, 저장이면 관리자 기록 (대상 id = 종류 이름)
  @PostMapping(PAGE_PATH + "/{type}")
  public String save(@PathVariable("type") String typeName,
    @RequestParam(name = "enabled", defaultValue = "false") boolean isEnabled,
    @RequestParam(name = "titleTemplate", required = false) String titleTemplate,
    @RequestParam(name = "bodyTemplate", required = false) String bodyTemplate,
    @RequestParam(name = "route", required = false) String routeWire,
    @RequestParam(name = "sendHour", required = false) Integer sendHour,
    @RequestParam(name = "sendMinute", required = false) Integer sendMinute,
    @RequestParam(name = "minIntervalDays", required = false) Integer minIntervalDays,
    Authentication authentication, RedirectAttributes redirectAttributes) {
    Optional<AutoNotificationType> type = typeOf(typeName);
    if (type.isEmpty()) {
      redirectAttributes.addFlashAttribute("errorMessage", "모르는 알림 종류예요");
      return REDIRECT_TO_PAGE;
    }
    RuleUpdateResult result = autoNotificationRuleService.update(type.get(),
      new RuleUpdate(isEnabled, titleTemplate, bodyTemplate, routeWire, sendHour, sendMinute, minIntervalDays),
      authentication == null ? null : authentication.getName());
    if (!result.isSaved()) {
      redirectAttributes.addFlashAttribute("errorMessage", type.get().getLabel() + ": " + result.rejectionMessage());
      return REDIRECT_TO_PAGE;
    }
    adminAuditService.record(AdminAuditAction.AUTO_NOTIFICATION_RULE_UPDATED, type.get().name(), result.changeSummary());
    redirectAttributes.addFlashAttribute("message", "'" + type.get().getLabel() + "' 규칙을 저장했어요.");
    return REDIRECT_TO_PAGE;
  }

  private static Optional<AutoNotificationType> typeOf(String typeName) {
    for (AutoNotificationType type : AutoNotificationType.values()) {
      if (type.name().equals(typeName)) {
        return Optional.of(type);
      }
    }
    return Optional.empty();
  }
}
