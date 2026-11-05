package com.chuseok22.elumserver.member.core;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** 이룸이 호칭 규칙 (#1129). 공백 없는 긴 이름이 이룸이 보상 화면을 깨뜨리지 않게 서버도 같은 상한으로 거절 */
class ElumiNicknameTest {

  @Test
  @DisplayName("20자까지 받고 21자부터 400 INVALID_INPUT_VALUE 로 거절한다")
  void maxLength() {
    assertThat(ElumiNickname.normalize("가".repeat(20))).hasSize(20);
    assertThatThrownBy(() -> ElumiNickname.normalize("Haneul".repeat(7)))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.INVALID_INPUT_VALUE);
  }

  @Test
  @DisplayName("앞뒤 공백은 잘라서 세고 저장한다")
  void trimsBeforeCounting() {
    assertThat(ElumiNickname.normalize("  " + "가".repeat(20) + " ")).isEqualTo("가".repeat(20));
  }

  @Test
  @DisplayName("줄바꿈이 섞이면 거절한다 — 이룸이 화면에 그대로 나간다")
  void rejectsLineBreak() {
    assertThatThrownBy(() -> ElumiNickname.normalize("하\n늘")).isInstanceOf(CustomException.class);
  }
}
