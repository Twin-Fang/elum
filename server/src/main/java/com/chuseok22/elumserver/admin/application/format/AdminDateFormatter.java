package com.chuseok22.elumserver.admin.application.format;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import org.springframework.stereotype.Component;

/**
 * 관리자 화면 날짜 표기 단일 원본: yyyy-MM-dd HH:mm, 값 없으면 "-"
 * 템플릿에서 ${@adminDate.format(값)}
 */
@Component("adminDate")
public class AdminDateFormatter {

  private static final DateTimeFormatter ADMIN_DATE_TIME = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm");
  private static final String EMPTY_DATE_TEXT = "-";

  public String format(LocalDateTime dateTime) {
    return dateTime == null ? EMPTY_DATE_TEXT : ADMIN_DATE_TIME.format(dateTime);
  }
}
