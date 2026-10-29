package com.chuseok22.elumserver.admin.application.list;

import java.time.LocalDate;
import java.time.format.DateTimeParseException;

/**
 * 화면 날짜 파라미터(yyyy-MM-dd) > 날짜. 비었거나 형식이 틀리면 null (화면이 깨지지 않게 부르는 쪽이 기본값으로)
 */
public final class AdminDateParameter {

  private AdminDateParameter() {
  }

  public static LocalDate parseOrNull(String text) {
    if (text == null || text.isBlank()) {
      return null;
    }
    try {
      return LocalDate.parse(text.trim());
    } catch (DateTimeParseException e) {
      return null;
    }
  }
}
