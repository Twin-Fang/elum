package com.chuseok22.elumserver.notification.application.service;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;

/**
 * 자동 알림 문구 틀 > 받는 사람 문구 (#1275)
 * 변수 3개: {아이이름} 이룸이 이름, {일과} 최근 보낸 일과 제목, {날짜} M월 d일 (값이 없으면 기본 말)
 */
public final class AutoNotificationTemplate {

  public static final String CHILD_NAME_VARIABLE = "{아이이름}";
  public static final String ROUTINE_TITLE_VARIABLE = "{일과}";
  public static final String DATE_VARIABLE = "{날짜}";
  public static final List<String> VARIABLES = List.of(CHILD_NAME_VARIABLE, ROUTINE_TITLE_VARIABLE, DATE_VARIABLE);

  // 값이 없을 때 넣는 말
  static final String DEFAULT_CHILD_NAME = "이룸이";
  static final String DEFAULT_ROUTINE_TITLE = "일과";
  private static final DateTimeFormatter KOREAN_MONTH_DAY = DateTimeFormatter.ofPattern("M월 d일");

  private AutoNotificationTemplate() {
  }

  /// 날짜 > "2월 12일"
  public static String toKoreanMonthDay(LocalDate date) {
    return date == null ? "" : KOREAN_MONTH_DAY.format(date);
  }

  /// 틀의 변수를 값으로 바꾸고 최대 글자 수로 자름 (빈 값은 기본 말)
  public static String render(String template, AutoNotificationCandidate candidate, int maximumLength) {
    if (template == null) {
      return "";
    }
    String rendered = template
      .replace(CHILD_NAME_VARIABLE, valueOrDefault(candidate.childName(), DEFAULT_CHILD_NAME))
      .replace(ROUTINE_TITLE_VARIABLE, valueOrDefault(candidate.routineTitle(), DEFAULT_ROUTINE_TITLE))
      .replace(DATE_VARIABLE, valueOrDefault(candidate.dateText(), ""))
      .strip();
    return rendered.length() > maximumLength ? rendered.substring(0, maximumLength) : rendered;
  }

  private static String valueOrDefault(String value, String defaultValue) {
    return value == null || value.isBlank() ? defaultValue : value.strip();
  }
}
