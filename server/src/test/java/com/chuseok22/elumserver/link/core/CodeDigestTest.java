package com.chuseok22.elumserver.link.core;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.link.application.service.DeviceLinkService;
import java.time.Duration;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** 연결 암호와 초대 코드가 함께 쓰는 규칙 (이슈 #361). 한쪽만 바뀌어 어긋나지 않게 고정한다. */
class CodeDigestTest {

  @Test
  @DisplayName("해시는 SHA-256 소문자 16진수 64자이고 원문과 같지 않다")
  void sha256_hexOfFixedLength() {
    String hash = CodeDigest.sha256("A7K3M9");

    assertThat(hash).hasSize(64).matches("[0-9a-f]{64}").isNotEqualTo("A7K3M9");
    assertThat(CodeDigest.sha256("A7K3M9")).isEqualTo(hash);
    assertThat(CodeDigest.sha256("A7K3M8")).isNotEqualTo(hash);
  }

  @Test
  @DisplayName("연결 암호는 이 부품과 같은 유효 시간·실패 횟수를 쓴다 — 코드 둘의 규칙이 갈라지지 않는다")
  void deviceLinkUsesTheSharedRules() {
    assertThat(DeviceLinkService.CODE_TTL).isEqualTo(CodeDigest.CODE_TTL).isEqualTo(Duration.ofMinutes(10));
    assertThat(DeviceLinkService.MAX_FAILED_ATTEMPTS).isEqualTo(CodeDigest.MAX_FAILED_ATTEMPTS).isEqualTo(5);
  }
}
