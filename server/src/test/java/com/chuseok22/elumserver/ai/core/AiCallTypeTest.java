package com.chuseok22.elumserver.ai.core;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.EnumSet;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 호출 유형의 분류를 고정한다 (#367).
 *
 * <p>요금제 한도는 "일과 생성" 으로 분류된 유형만 센다. 새 제공자를 더하면서 분류를 잘못
 * 두면 그 제공자로 만든 일과가 한도에서 빠진다 — Gemini 만 세던 가드가 OpenAI 로 바꾸자
 * 조용히 풀렸던 것과 같은 일이다.
 */
class AiCallTypeTest {

  /// 유형마다 무엇을 위한 호출인지. 새 유형을 더하면 여기에 분류를 적어야 테스트가 통과한다.
  private static final Map<AiCallType, AiCallPurpose> EXPECTED = Map.of(
    AiCallType.GEMINI_TEXT_CREATE, AiCallPurpose.ROUTINE_CREATE,
    AiCallType.OPENAI_TEXT_CREATE, AiCallPurpose.ROUTINE_CREATE,
    AiCallType.GEMINI_TEXT_QUESTION, AiCallPurpose.ROUTINE_QUESTION,
    AiCallType.OPENAI_TEXT_QUESTION, AiCallPurpose.ROUTINE_QUESTION,
    AiCallType.GEMINI_IMAGE, AiCallPurpose.CARD_IMAGE,
    AiCallType.OPENAI_IMAGE, AiCallPurpose.CARD_IMAGE,
    AiCallType.FLUX_IMAGE, AiCallPurpose.CARD_IMAGE,
    AiCallType.LOCAL_LLM_DLP, AiCallPurpose.SENSITIVE_INFO_CHECK
  );

  @Test
  @DisplayName("모든 호출 유형의 분류가 정해져 있다 — 새 유형을 더하면 분류를 정할 때까지 실패한다")
  void everyTypeHasDecidedPurpose() {
    assertThat(EXPECTED.keySet()).containsExactlyInAnyOrderElementsOf(EnumSet.allOf(AiCallType.class));
    EXPECTED.forEach((type, purpose) ->
      assertThat(type.getPurpose()).as(type.name()).isEqualTo(purpose));
  }

  @Test
  @DisplayName("일과 생성 집계 대상은 제공자별 일과 생성 호출 전부다")
  void routineCreateTypes_coverEveryProvider() {
    assertThat(AiCallType.routineCreateTypes())
      .containsExactlyInAnyOrder(AiCallType.GEMINI_TEXT_CREATE, AiCallType.OPENAI_TEXT_CREATE);
  }

  @Test
  @DisplayName("이름이 _TEXT_CREATE 로 끝나는 유형은 빠짐없이 일과 생성 집계에 든다")
  void everyTextCreateType_isCounted() {
    // 분류 표를 고치면서 새 제공자를 다른 분류로 잘못 적어도 여기서 잡힌다.
    for (AiCallType type : AiCallType.values()) {
      if (type.name().endsWith("_TEXT_CREATE")) {
        assertThat(AiCallType.routineCreateTypes()).as(type.name()).contains(type);
      }
    }
  }
}
