package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.common.locale.AppLocale;

// 프롬프트 화면 언어 탭 한 칸: enabled 일과 생성 가능 언어로 켜짐, missingCount 아직 없는 프롬프트 행 수
public record PromptLocaleView(String code, String label, boolean enabled, int missingCount) {

  public static PromptLocaleView of(AppLocale locale, boolean enabled, int missingCount) {
    String label = switch (locale) {
      case KO -> "한국어 (ko)";
      case EN -> "English (en)";
      case JA -> "日本語 (ja)";
      case ZH -> "简体中文 (zh)";
      case ES -> "Español (es)";
    };
    return new PromptLocaleView(locale.code(), label, enabled, missingCount);
  }
}
