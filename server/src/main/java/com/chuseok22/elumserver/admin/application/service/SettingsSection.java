package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.systemconfig.core.ConfigGroup;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 설정을 보여 주고 고치는 관리자 화면 6개: 시스템, AI, 요금제·구독, 광고 보상, 공지, 서버 이전
 * 설정 묶음 > 화면 대응은 of() 한 곳 (default 없음: 새 묶음은 화면을 정해야 컴파일됨)
 */
@Getter
@AllArgsConstructor
public enum SettingsSection {

  SYSTEM("시스템 설정", "/admin/settings"),
  AI("AI 설정", "/admin/settings/ai"),
  PLAN("요금제·구독", "/admin/settings/plans"),
  AD_REWARD("광고 보상", "/admin/ad-rewards"),
  NOTICE("공지 관리", "/admin/notices"),
  MIGRATION("서버 이전", "/admin/migration"),
  ;

  // 다른 화면 설정을 열 때 붙이는 주소 조각: {path}#setting={KEY} > 그 화면이 패널을 연다
  private static final String OPEN_SETTING_FRAGMENT = "#setting=";

  private final String label;
  private final String path;

  /// 설정 묶음 > 그 묶음을 고치는 화면
  public static SettingsSection of(ConfigGroup group) {
    return switch (group) {
      case MEMBER, USAGE_LIMIT, APP_CONTROL, APP_TUNING, LANGUAGE, MAIL, CONTROL_TOWER, WEEKLY_REPORT -> SYSTEM;
      case GEMINI_TEXT, GEMINI_IMAGE, IMAGE_PROVIDER, TEXT_PROVIDER, PRICING, AI_BUDGET -> AI;
      case PLAN_FREE, PLAN_PRO, SIGNUP_PRO_EVENT, EXISTING_MEMBER_PRO_GIFT, SUBSCRIPTION_STORE -> PLAN;
      case AD_REWARD -> AD_REWARD;
      case NOTICE -> NOTICE;
      case MIGRATION -> MIGRATION;
    };
  }

  public static SettingsSection of(ConfigKey key) {
    return of(key.getGroup());
  }

  /// 설정 키 > 그 화면에서 그 설정 패널을 여는 주소 (예: /admin/settings/ai#setting=AI_DAILY_BUDGET_USD)
  public static String openPathOf(String key) {
    return of(ConfigKey.valueOf(key)).getPath() + OPEN_SETTING_FRAGMENT + key;
  }

  /// 폼 제출 뒤 돌아갈 화면
  public String redirectView() {
    return "redirect:" + path;
  }
}
