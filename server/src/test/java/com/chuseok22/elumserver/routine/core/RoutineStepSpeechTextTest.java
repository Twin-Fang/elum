package com.chuseok22.elumserver.routine.core;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

/**
 * 단계 음성 문장 규칙 (#675). 앱 speak 호출부와 어긋나면 제목이 빠지거나 설명이 두 번 읽힌다.
 */
class RoutineStepSpeechTextTest {

  @Test
  void 제목이_있으면_제목과_설명을_잇는다() {
    assertThat(RoutineStepSpeechText.of("옷을 입어요", "학교 갈 옷을 입어요"))
      .isEqualTo("옷을 입어요. 학교 갈 옷을 입어요");
  }

  @Test
  void 제목이_비면_설명을_제목으로_쓴다() {
    assertThat(RoutineStepSpeechText.of(null, "손을 씻어요")).isEqualTo("손을 씻어요. 손을 씻어요");
    assertThat(RoutineStepSpeechText.of("  ", "손을 씻어요")).isEqualTo("손을 씻어요. 손을 씻어요");
  }

  @Test
  void 같은_문장은_같은_해시이고_다르면_다르다() {
    String hash = RoutineStepSpeechText.hashOf("손을 씻어요. 손을 씻어요");

    assertThat(hash).hasSize(16).isEqualTo(RoutineStepSpeechText.hashOf("손을 씻어요. 손을 씻어요"));
    assertThat(RoutineStepSpeechText.hashOf("이를 닦아요. 이를 닦아요")).isNotEqualTo(hash);
  }
}
