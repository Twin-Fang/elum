package com.chuseok22.elumserver.common.infrastructure.logging;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class LogInstanceTest {

  @Test
  @DisplayName("blue/green 만 인정하고 나머지는 local 로 본다")
  void normalize() {
    assertThat(LogInstance.normalize("blue")).isEqualTo("blue");
    assertThat(LogInstance.normalize(" GREEN ")).isEqualTo("green");
    assertThat(LogInstance.normalize(null)).isEqualTo("local");
    assertThat(LogInstance.normalize("")).isEqualTo("local");
    assertThat(LogInstance.normalize("../etc")).isEqualTo("local");
  }

  @Test
  @DisplayName("반대 색은 blue↔green 이고 local 은 없다")
  void opposite() {
    assertThat(LogInstance.opposite("blue")).contains("green");
    assertThat(LogInstance.opposite("green")).contains("blue");
    assertThat(LogInstance.opposite("local")).isEmpty();
  }
}
