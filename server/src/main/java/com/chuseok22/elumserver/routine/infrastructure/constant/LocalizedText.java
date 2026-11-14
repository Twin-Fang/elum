package com.chuseok22.elumserver.routine.infrastructure.constant;

import com.chuseok22.elumserver.common.locale.AppLocale;

/**
 * 예시 일과 문장 1개의 다섯 언어 (ko · en · ja · zh · es)
 * 빈 언어는 영어로 대체
 */
public record LocalizedText(String ko, String en, String ja, String zh, String es) {

  /** 언어 > 그 언어 문장 (비면 영어) */
  public String in(AppLocale language) {
    String text = switch (language) {
      case KO -> ko;
      case EN -> en;
      case JA -> ja;
      case ZH -> zh;
      case ES -> es;
    };
    return text == null || text.isBlank() ? en : text;
  }
}
