package com.chuseok22.elumserver.systemconfig.application.service;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * 날짜시간 설정값 읽기: 2026-10-19T00:00, 2026-10-19 00:00, 2026-10-19(그날 00:00)
 */
public final class ConfigDateTime {

  private static final int DATE_ONLY_LENGTH = 10;

  private ConfigDateTime() {
  }

  // 문자열 > 시각 (읽을 수 없으면 DateTimeParseException)
  public static LocalDateTime parse(String rawValue) {
    String value = rawValue.trim().replace(' ', 'T');
    if (value.length() == DATE_ONLY_LENGTH) {
      return LocalDate.parse(value).atStartOfDay();
    }
    return LocalDateTime.parse(value);
  }
}
