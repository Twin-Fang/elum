package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.common.locale.AppLocale;

/**
 * 약관 화면 언어 탭 한 칸: missingCount 아직 없는 약관 수, isPublished 앱에 그 언어로 나감(필수 4종 모두 있음)
 */
public record ConsentLocaleView(String code, String label, int missingCount, boolean isPublished) {

  public static ConsentLocaleView of(AppLocale locale, int missingCount, boolean isPublished) {
    String label = switch (locale) {
      case KO -> "한국어 (ko)";
      case EN -> "English (en)";
      case JA -> "日本語 (ja)";
      case ZH -> "简体中文 (zh)";
      case ES -> "Español (es)";
    };
    return new ConsentLocaleView(locale.code(), label, missingCount, isPublished);
  }
}
