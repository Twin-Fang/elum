package com.chuseok22.elumserver.systemconfig.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.LocalDateTime;
import java.time.format.DateTimeParseException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class ConfigDateTimeTest {

  @Test
  @DisplayName("T 구분·공백 구분·날짜만 세 형식을 모두 읽는다")
  void parsesSupportedFormats() {
    LocalDateTime expected = LocalDateTime.of(2026, 10, 19, 0, 0);

    assertThat(ConfigDateTime.parse("2026-10-19T00:00")).isEqualTo(expected);
    assertThat(ConfigDateTime.parse(" 2026-10-19 00:00 ")).isEqualTo(expected);
    assertThat(ConfigDateTime.parse("2026-10-19")).isEqualTo(expected);
  }

  @Test
  @DisplayName("읽을 수 없는 값은 예외다")
  void rejectsUnreadableValue() {
    assertThatThrownBy(() -> ConfigDateTime.parse("내일")).isInstanceOf(DateTimeParseException.class);
  }
}
