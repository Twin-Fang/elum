package com.chuseok22.elumserver.talk.core;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import org.junit.jupiter.api.Test;

/// 한마디 정리가 틀리면 빈 글이 저장되거나, 제어문자가 다른 보호자 화면에 그대로 나간다.
class TalkTextRulesTest {

  @Test
  void normalizeNote_blankBecomesNull() {
    assertThat(TalkTextRules.normalizeNote(null)).isNull();
    assertThat(TalkTextRules.normalizeNote("  \n ")).isNull();
  }

  @Test
  void normalizeNote_stripsAndKeepsNewlineButRemovesOtherControlCharacters() {
    assertThat(TalkTextRules.normalizeNote("  첫 줄\r\n둘째\t줄\u0007  ")).isEqualTo("첫 줄\n둘째줄");
  }

  @Test
  void normalizeNote_limitIsCodePointsNotUtf16Units() {
    // 이모지는 UTF-16 으로 2칸이지만 한 글자로 센다
    assertThat(TalkTextRules.normalizeNote("😀".repeat(300))).hasSize(600);
    assertThatThrownBy(() -> TalkTextRules.normalizeNote("😀".repeat(301)))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_TEXT_TOO_LONG));
  }

  @Test
  void normalizeComment_blankOrNullIsInvalidInput() {
    assertThatThrownBy(() -> TalkTextRules.normalizeComment(" \n "))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.INVALID_INPUT_VALUE));
    assertThatThrownBy(() -> TalkTextRules.normalizeComment(null))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.INVALID_INPUT_VALUE));
  }

  @Test
  void normalizeComment_stripsAndLimitsToThreeHundredCodePoints() {
    assertThat(TalkTextRules.normalizeComment("  좋아요 \n")).isEqualTo("좋아요");
    assertThatThrownBy(() -> TalkTextRules.normalizeComment("가".repeat(301)))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_TEXT_TOO_LONG));
  }
}
