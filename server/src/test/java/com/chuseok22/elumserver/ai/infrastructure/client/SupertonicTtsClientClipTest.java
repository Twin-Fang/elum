package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * AI 서버 문장 제한 500자 (#675). 이모지가 반으로 잘리면 JSON 이 깨져 같은 400 이 계속 반복된다.
 */
class SupertonicTtsClientClipTest {

  @Test
  @DisplayName("500자 이하는 그대로 보낸다")
  void clip_short_unchanged() {
    assertThat(SupertonicTtsClient.clip("손을 씻어요")).isEqualTo("손을 씻어요");
  }

  @Test
  @DisplayName("500자를 넘으면 500자로 자른다")
  void clip_long_cutsAt500() {
    assertThat(SupertonicTtsClient.clip("가".repeat(600))).hasSize(500);
  }

  @Test
  @DisplayName("경계에서 이모지(두 칸 글자)가 반으로 잘리지 않는다")
  void clip_doesNotSplitSurrogatePair() {
    String text = "가".repeat(499) + "😀" + "나".repeat(10);

    String clipped = SupertonicTtsClient.clip(text);

    assertThat(clipped).hasSize(499);
    assertThat(Character.isHighSurrogate(clipped.charAt(clipped.length() - 1))).isFalse();
  }
}
