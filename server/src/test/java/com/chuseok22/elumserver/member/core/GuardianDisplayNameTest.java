package com.chuseok22.elumserver.member.core;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** 함께하는 사람을 부르는 이름의 규칙 (#361). 다른 보호자와 이룸이 폰 화면에 그대로 나가는 값이다. */
class GuardianDisplayNameTest {

  @Test
  @DisplayName("앞뒤 공백을 자른다")
  void trims() {
    assertThat(GuardianDisplayName.normalize("  엄마 ")).isEqualTo("엄마");
  }

  @Test
  @DisplayName("null 과 공백뿐인 값은 이름 없음(null)이다")
  void blankMeansNoName() {
    assertThat(GuardianDisplayName.normalize(null)).isNull();
    assertThat(GuardianDisplayName.normalize("")).isNull();
    assertThat(GuardianDisplayName.normalize("   ")).isNull();
  }

  @Test
  @DisplayName("20자까지 받고 21자부터 거절한다 — 컬럼은 30이라 20은 넉넉하다")
  void maxLength() {
    assertThat(GuardianDisplayName.normalize("가".repeat(20))).hasSize(20);
    assertThatThrownBy(() -> GuardianDisplayName.normalize("가".repeat(21)))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.INVALID_INPUT_VALUE);
  }

  @Test
  @DisplayName("글자 수는 코드포인트로 센다 — 이모지 하나를 둘로 세지 않는다")
  void countsCodePoints() {
    assertThat(GuardianDisplayName.normalize("👨".repeat(20))).isNotNull();
    assertThatThrownBy(() -> GuardianDisplayName.normalize("👨".repeat(21)))
      .isInstanceOf(CustomException.class);
  }

  @Test
  @DisplayName("줄바꿈·제어 문자가 섞이면 거절한다 — 화면에 그대로 나간다")
  void rejectsControlCharacters() {
    assertThatThrownBy(() -> GuardianDisplayName.normalize("엄\n마")).isInstanceOf(CustomException.class);
    assertThatThrownBy(() -> GuardianDisplayName.normalize("엄\u0000마")).isInstanceOf(CustomException.class);
  }
}
