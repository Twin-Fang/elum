package com.chuseok22.elumserver.routine.infrastructure.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.TextGenerationClient;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleType;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 수정 찾기 응답 파싱: 깨지면 알 수 없는 종류 한 건이 이번 일과 전체를 버리거나, 형식이 틀린 응답이 빈 결과로 조용히 넘어간다
 */
@ExtendWith(MockitoExtension.class)
class RoutineMemoryAiTest {

  @Mock private TextClientRouter textClientRouter;
  @Mock private TextGenerationClient textGenerationClient;
  @InjectMocks private RoutineMemoryAi routineMemoryAi;

  private static RoutineMemoryAi.ExtractionInput input() {
    return RoutineMemoryAi.ExtractionInput.of(List.of("옷 / 착용해요"), List.of("옷 / 입어요"), List.of(), List.of());
  }

  @Test
  @DisplayName("matched 와 found 를 읽고, 알 수 없는 종류 한 건만 버린다")
  void parsesMatchedAndFoundAndDropsUnknownType() {
    when(textClientRouter.current()).thenReturn(textGenerationClient);
    when(textGenerationClient.buildRoutineMemoryJson(anyString())).thenReturn("""
      {"matched": ["rule-1"], "found": [
        {"type": "WORD", "before": "착용해요", "after": "입어요", "summary": "착용해요 대신 입어요"},
        {"type": "MAGIC", "before": "가", "after": "나", "summary": "x"},
        {"type": "ADD", "before": null, "after": "물 마시기", "summary": "물 마시기를 넣어요"}]}
      """);

    RoutineMemoryAi.ExtractionResult result = routineMemoryAi.extract(input());

    assertThat(result.matchedRuleIds()).containsExactly("rule-1");
    assertThat(result.foundFindings()).extracting(finding -> finding.type())
      .containsExactly(RoutineMemoryRuleType.WORD, RoutineMemoryRuleType.ADD);
    assertThat(result.foundFindings().get(1).before()).isNull();
  }

  @Test
  @DisplayName("matched·found 배열이 없는 응답은 던진다 — 형식 오류가 '찾을 것 없음'으로 넘어가지 않게")
  void missingArrays_throws() {
    when(textClientRouter.current()).thenReturn(textGenerationClient);
    when(textGenerationClient.buildRoutineMemoryJson(anyString())).thenReturn("{\"lines\": []}");

    assertThatThrownBy(() -> routineMemoryAi.extract(input())).isInstanceOf(IllegalStateException.class);
  }

  @Test
  @DisplayName("AI 입력 JSON 에는 카드 글·규칙만 있고 일과 제목·원문·이름 칸이 없다")
  void inputJsonHasOnlyCardsAndRules() {
    String json = RoutineMemoryAi.toJson(input());

    assertThat(json).contains("firstCards", "confirmedCards", "existingRules", "rejectedRules");
    assertThat(json).doesNotContain("routineTitle", "rawInputText", "nickname", "memberId");
  }
}
