package com.chuseok22.elumserver.routine.infrastructure.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anySet;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.infrastructure.client.GeminiGenerateContentResponse;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiImageClient;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiTextClient;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class RoutineAiPipelineTest {

  @Mock
  private GeminiTextClient geminiTextClient;

  @Mock
  private GeminiImageClient geminiImageClient;

  @Mock
  private RoutineImageStorage routineImageStorage;

  @InjectMocks
  private RoutineAiPipeline routineAiPipeline;

  private GeminiGenerateContentResponse textResponse(String json) {
    return new GeminiGenerateContentResponse(List.of(
      new GeminiGenerateContentResponse.Candidate(new GeminiGenerateContentResponse.Content(List.of(
        new GeminiGenerateContentResponse.Part(json, null)
      )))
    ));
  }

  @Test
  @DisplayName("Gemini가 유효한 questions 배열을 반환하면 그대로 변환해서 반환한다")
  void generateQuestion_validResponse_returnsMappedQuestions() {
    String json = "{\"questions\":[{\"question\":\"준비물이 있나요?\",\"options\":[\"우산\",\"우비\"]},"
      + "{\"question\":\"평소와 다른 점이 있나요?\",\"options\":[\"시간 변경\",\"장소 변경\"]}]}";
    when(geminiTextClient.generateQuestion(eq("하늘이"), anySet(), eq("내일 비 오는 날")))
      .thenReturn(textResponse(json));

    RoutineAiPipeline.RoutineQuestionResult result = routineAiPipeline.generateQuestion(
      "하늘이", Set.of(SupportGoal.PREPARE_ITEMS, SupportGoal.PREPARE_NEW), "내일 비 오는 날"
    );

    assertThat(result.questions()).hasSize(2);
    assertThat(result.questions().get(0).question()).isEqualTo("준비물이 있나요?");
    assertThat(result.questions().get(1).options()).containsExactly("시간 변경", "장소 변경");
  }

  @Test
  @DisplayName("Gemini 호출이 실패하면 선택한 도움 목표별 고정 질문으로 대체한다")
  void generateQuestion_geminiFails_fallsBackToGoalMappedQuestions() {
    when(geminiTextClient.generateQuestion(any(), any(), any()))
      .thenThrow(new RuntimeException("Gemini 호출 실패"));

    RoutineAiPipeline.RoutineQuestionResult result = routineAiPipeline.generateQuestion(
      "하늘이", Set.of(SupportGoal.PREPARE_ITEMS, SupportGoal.PREPARE_NEW), "내일 비 오는 날"
    );

    assertThat(result.questions()).hasSize(2);
  }

  @Test
  @DisplayName("Gemini 응답에 questions가 없으면 fallback으로 대체한다")
  void generateQuestion_emptyQuestions_fallsBack() {
    when(geminiTextClient.generateQuestion(any(), any(), any()))
      .thenReturn(textResponse("{\"questions\":[]}"));

    RoutineAiPipeline.RoutineQuestionResult result = routineAiPipeline.generateQuestion(
      "하늘이", Set.of(SupportGoal.PREPARE_ITEMS), "내일 비 오는 날"
    );

    assertThat(result.questions()).hasSize(1);
    assertThat(result.questions().get(0).question()).isEqualTo("꼭 챙겨야 하는 준비물이 있나요?");
  }
}
