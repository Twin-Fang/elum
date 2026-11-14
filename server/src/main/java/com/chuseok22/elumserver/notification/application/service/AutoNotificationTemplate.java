package com.chuseok22.elumserver.notification.application.service;

import java.util.List;

/**
 * 자동 알림 문구 틀 > 받는 사람 문구 (#1275)
 * 변수 3개: {아이이름} 이룸이 이름, {일과} 최근 보낸 일과 제목, {날짜} 언어별 날짜 (값이 없으면 언어별 기본 말)
 */
public final class AutoNotificationTemplate {

  public static final String CHILD_NAME_VARIABLE = "{아이이름}";
  public static final String ROUTINE_TITLE_VARIABLE = "{일과}";
  public static final String DATE_VARIABLE = "{날짜}";
  public static final List<String> VARIABLES = List.of(CHILD_NAME_VARIABLE, ROUTINE_TITLE_VARIABLE, DATE_VARIABLE);

  private AutoNotificationTemplate() {
  }

  /// 값이 없을 때 넣는 말과 날짜 글자 (언어마다 다름, AutoNotificationCopyResolver 가 채움)
  public record Fallbacks(String defaultChildName, String defaultRoutineTitle, String dateText) {
  }

  /// 틀의 변수를 값으로 바꾸고 최대 글자 수로 자름 (빈 값은 기본 말)
  public static String render(String template, AutoNotificationCandidate candidate, Fallbacks fallbacks,
    int maximumLength) {
    if (template == null) {
      return "";
    }
    String rendered = template
      .replace(CHILD_NAME_VARIABLE, valueOrDefault(candidate.childName(), fallbacks.defaultChildName()))
      .replace(ROUTINE_TITLE_VARIABLE, valueOrDefault(candidate.routineTitle(), fallbacks.defaultRoutineTitle()))
      .replace(DATE_VARIABLE, valueOrDefault(fallbacks.dateText(), ""))
      .strip();
    return rendered.length() > maximumLength ? rendered.substring(0, maximumLength) : rendered;
  }

  private static String valueOrDefault(String value, String defaultValue) {
    return value == null || value.isBlank() ? defaultValue : value.strip();
  }
}
