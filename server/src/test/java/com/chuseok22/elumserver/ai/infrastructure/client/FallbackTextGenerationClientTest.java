package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 텍스트 제공자 사슬 (#1083): 실패·쓸 수 없는 답이면 다음 제공자로
 * 깨지면: Claude 크레딧이 떨어진 날 일과 만들기가 Gemini 로 넘어가지 않고 실패함
 */
class FallbackTextGenerationClientTest {

  private static final String VALID_ROUTINE = "{\"title\":\"이를 닦아요\",\"steps\":[{\"order\":1,\"title\":\"이를 닦아요\"}]}";

  private final TextGenerationClient first = mock(TextGenerationClient.class);
  private final TextGenerationClient second = mock(TextGenerationClient.class);
  private final FallbackTextGenerationClient chain = new FallbackTextGenerationClient(List.of(first, second));

  @Test
  @DisplayName("1번 제공자가 예외면 같은 요청을 2번 제공자로 보내 그 결과를 쓴다")
  void firstThrows_secondServes() {
    when(first.generateRoutineJson(any(), any(), any(), any(), anyBoolean())).thenThrow(new IllegalStateException("529"));
    when(second.generateRoutineJson(any(), any(), any(), any(), anyBoolean())).thenReturn(VALID_ROUTINE);

    assertThat(chain.generateRoutineJson("양치", null, java.util.Set.of(), List.of(), true)).isEqualTo(VALID_ROUTINE);
  }

  @Test
  @DisplayName("1번이 제목·단계 없는 JSON 이나 깨진 JSON 을 주면 2번으로 넘긴다")
  void unusableJson_movesOn() {
    when(first.generateRoutineJson(any(), any(), any(), any(), anyBoolean())).thenReturn("{\"title\":\"\",\"steps\":[]}");
    when(second.generateRoutineJson(any(), any(), any(), any(), anyBoolean())).thenReturn(VALID_ROUTINE);
    when(first.generateQuestionJson(any(), any(), any())).thenReturn("not json");
    when(second.generateQuestionJson(any(), any(), any())).thenReturn("{\"questions\":[{\"supportGoal\":\"PREPARE_ITEMS\"}]}");

    assertThat(chain.generateRoutineJson("양치", null, java.util.Set.of(), List.of(), false)).isEqualTo(VALID_ROUTINE);
    assertThat(chain.generateQuestionJson(null, java.util.Set.of(), "마트")).contains("PREPARE_ITEMS");
  }

  @Test
  @DisplayName("1번이 카드 0장으로 답하면 2번을 부르지 않는다 — 넘기면 2번이 카드를 지어낼 수 있다")
  void emptySteps_doesNotMoveOn() {
    String noCards = "{\"title\":\"어떤 일과인지 알려 주세요\",\"steps\":[]}";
    when(first.generateRoutineJson(any(), any(), any(), any(), anyBoolean())).thenReturn(noCards);

    assertThat(chain.generateRoutineJson("ㅁㄴㅇㄹ", null, java.util.Set.of(), List.of(), false)).isEqualTo(noCards);
    verify(second, never()).generateRoutineJson(any(), any(), any(), any(), anyBoolean());
  }

  @Test
  @DisplayName("마지막 제공자의 실패는 그대로 던진다 — 부르는 쪽의 기존 실패 처리(폴백 질문 등)가 받는다")
  void lastFailure_propagates() {
    when(first.pickPictogramJson("t", "d")).thenThrow(new IllegalStateException("first"));
    when(second.pickPictogramJson("t", "d")).thenThrow(new IllegalStateException("second"));

    assertThatThrownBy(() -> chain.pickPictogramJson("t", "d")).hasMessage("second");
  }

  @Test
  @DisplayName("일과 번역(#1077)도 1번이 실패하면 2번으로 넘긴다 — 안 넘기면 Claude 크레딧이 떨어진 날 번역만 실패함")
  void translate_movesOnWhenFirstFails() {
    var draft = new com.chuseok22.elumserver.ai.core.RoutineTranslationDraft("아침", null, List.of());
    var ko = com.chuseok22.elumserver.common.locale.AppLocale.KO;
    var en = com.chuseok22.elumserver.common.locale.AppLocale.EN;
    when(first.translateRoutineJson(draft, ko, en)).thenThrow(new IllegalStateException("529"));
    when(second.translateRoutineJson(draft, ko, en)).thenReturn(VALID_ROUTINE);

    assertThat(chain.translateRoutineJson(draft, ko, en)).isEqualTo(VALID_ROUTINE);
  }

  @Test
  @DisplayName("관리자 시험은 1번 제공자만 부른다 — 다른 제공자 답이 섞이면 시험 결과를 믿을 수 없다")
  void adminTest_usesFirstOnly() {
    when(first.generateRoutineJsonForTest("prompt", "sample")).thenThrow(new IllegalStateException("fail"));

    assertThatThrownBy(() -> chain.generateRoutineJsonForTest("prompt", "sample")).hasMessage("fail");
    verify(second, never()).generateRoutineJsonForTest(any(), any());
  }
}
