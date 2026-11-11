package com.chuseok22.elumserver.routine.core;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import java.util.Arrays;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 보호자 요청 > 그림 지시문: 깨지면 요청이 그림에 반영되지 않거나, 긴 글·줄바꿈이 지시문을 흐트러뜨린다
 */
class GuardianImageRequestTest {

  @Test
  @DisplayName("칩 영어 문장(중복 제거·보낸 순서) 뒤에 보호자 글을 Guardian note 로 붙인다")
  void compose_hintsThenNote() {
    String composed = GuardianImageRequest.compose("  우산을\n파란색으로 ",
      Arrays.asList(ImageRedrawHint.BRIGHTER, ImageRedrawHint.NO_BACKGROUND, ImageRedrawHint.BRIGHTER, null));

    assertThat(composed).isEqualTo(ImageRedrawHint.BRIGHTER.getInstruction() + " "
      + ImageRedrawHint.NO_BACKGROUND.getInstruction() + " Guardian note: 우산을 파란색으로");
  }

  @Test
  @DisplayName("글·칩이 모두 비면 null — 같은 조건으로 다시 그린다")
  void compose_empty_null() {
    assertThat(GuardianImageRequest.compose(null, null)).isNull();
    assertThat(GuardianImageRequest.compose("   ", List.of())).isNull();
  }

  @Test
  @DisplayName("글은 60자까지 받고 61자부터 INVALID_INPUT_VALUE")
  void compose_lengthLimit() {
    assertThat(GuardianImageRequest.compose("가".repeat(60), null)).endsWith("가".repeat(60));
    assertThatThrownBy(() -> GuardianImageRequest.compose("가".repeat(61), null))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.INVALID_INPUT_VALUE);
  }
}
