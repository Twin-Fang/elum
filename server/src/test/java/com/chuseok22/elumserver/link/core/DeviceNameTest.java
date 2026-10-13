package com.chuseok22.elumserver.link.core;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class DeviceNameTest {

  @Test
  @DisplayName("비었거나 제어 문자뿐이면 이름 없음이다 — 연결은 막지 않는다")
  void blankBecomesNull() {
    assertThat(DeviceName.sanitize(null)).isNull();
    assertThat(DeviceName.sanitize("   ")).isNull();
    assertThat(DeviceName.sanitize("\n\t\u0000")).isNull();
  }

  @Test
  @DisplayName("너무 길면 코드포인트 기준으로 잘라 저장한다")
  void truncates() {
    String longName = "가".repeat(100);
    assertThat(DeviceName.sanitize(longName).codePointCount(0, DeviceName.sanitize(longName).length()))
      .isEqualTo(DeviceName.MAX_LENGTH);
  }
}
