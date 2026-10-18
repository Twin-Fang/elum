package com.chuseok22.elumserver.admin.application.format;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDateTime;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** 관리자 화면 날짜 표기: yyyy-MM-dd HH:mm 하나로 통일, 값이 없으면 "-". */
class AdminDateFormatterTest {

  private final AdminDateFormatter formatter = new AdminDateFormatter();

  @Test
  @DisplayName("분 단위까지 표기하고 초는 버린다")
  void format_dropsSeconds() {
    assertThat(formatter.format(LocalDateTime.of(2026, 10, 8, 7, 4, 59))).isEqualTo("2026-10-08 07:04");
  }

  @Test
  @DisplayName("null 은 '-' 로 표기한다")
  void format_nullIsDash() {
    assertThat(formatter.format(null)).isEqualTo("-");
  }
}
