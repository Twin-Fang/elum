package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.dto.response.PromptLocaleView;
import com.chuseok22.elumserver.admin.application.service.AdminLocaleStatusService;
import com.chuseok22.elumserver.common.locale.AppLocale;
import java.util.Arrays;
import java.util.Locale;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;

/**
 * 관리자 언어 현황 (읽기 전용): 언어별 준비 상태 표, 푸시 문구 ko <-> 고른 언어 비교
 */
@Controller
@RequiredArgsConstructor
public class AdminLocaleStatusController {

  private final AdminLocaleStatusService adminLocaleStatusService;

  // pushLocale: 푸시 문구 보기에서 ko 옆에 놓을 언어 (모르는 코드는 en)
  @GetMapping("/admin/locales")
  public String status(@RequestParam(value = "pushLocale", defaultValue = "en") String pushLocale, Model model) {
    AppLocale selectedPushLocale = parsePushLocale(pushLocale);
    model.addAttribute("rows", adminLocaleStatusService.getLocaleStatusRows());
    model.addAttribute("pushLocales", Arrays.stream(AppLocale.values())
      .filter(locale -> locale != AppLocale.KO)
      .map(locale -> PromptLocaleView.of(locale, false, 0))
      .toList());
    model.addAttribute("selectedPushLocale", selectedPushLocale.code());
    model.addAttribute("pushRows", adminLocaleStatusService.getPushMessageCompareRows(selectedPushLocale));
    return "admin/locales";
  }

  private AppLocale parsePushLocale(String code) {
    return AppLocale.findByCode(code == null ? null : code.trim().toLowerCase(Locale.ROOT))
      .filter(locale -> locale != AppLocale.KO)
      .orElse(AppLocale.EN);
  }
}
