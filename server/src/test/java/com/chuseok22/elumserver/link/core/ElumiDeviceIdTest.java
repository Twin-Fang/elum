package com.chuseok22.elumserver.link.core;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class ElumiDeviceIdTest {

  @Test
  @DisplayName("연결할 때 만든 기기 값에서 같은 연결 ID 를 되찾는다 — 만드는 쪽과 읽는 쪽이 어긋나면 이룸이가 보호자로 보인다")
  void roundTrip() {
    assertThat(ElumiDeviceId.of("l1")).isEqualTo("elumi-l1");
    assertThat(ElumiDeviceId.linkIdOf(ElumiDeviceId.of("l1"))).isEqualTo("l1");
  }

  @Test
  @DisplayName("보호자 기기 값이나 빈 값은 이룸이로 보지 않는다")
  void notElumi() {
    assertThat(ElumiDeviceId.linkIdOf("device-1")).isNull();
    assertThat(ElumiDeviceId.linkIdOf(null)).isNull();
    assertThat(ElumiDeviceId.linkIdOf("ELUMI-l1")).isNull();
  }
}
