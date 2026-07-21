package com.chuseok22.elumserver.routine.infrastructure.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.tuple;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anySet;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;

import com.chuseok22.elumserver.ai.infrastructure.client.GeminiGenerateContentResponse;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiImageClient;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiTextClient;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
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
  @DisplayName("Gemini가 목표별로 유효한 questions를 반환하면 emoji/label을 그대로 변환해서 반환한다")
  void generateQuestion_validResponse_returnsMappedQuestions() {
    String json = "{\"questions\":["
      + "{\"supportGoal\":\"PREPARE_ITEMS\",\"question\":\"준비물이 있나요?\",\"options\":["
      + "{\"emoji\":\"☔\",\"label\":\"우산\"},{\"emoji\":\"🧥\",\"label\":\"우비\"},"
      + "{\"emoji\":\"👖\",\"label\":\"장화\"}]},"
      + "{\"supportGoal\":\"PREPARE_NEW\",\"question\":\"평소와 다른 점이 있나요?\",\"options\":["
      + "{\"emoji\":\"⏰\",\"label\":\"시간 변경\"},{\"emoji\":\"📍\",\"label\":\"장소 변경\"},"
      + "{\"emoji\":\"👥\",\"label\":\"동행자 변경\"}]}]}";
    when(geminiTextClient.generateQuestion(eq("하늘이"), anySet(), eq("내일 비 오는 날")))
      .thenReturn(textResponse(json));

    RoutineAiPipeline.RoutineQuestionResult result = routineAiPipeline.generateQuestion(
      "하늘이", Set.of(SupportGoal.PREPARE_ITEMS, SupportGoal.PREPARE_NEW), "내일 비 오는 날"
    );

    assertThat(result.questions()).hasSize(2);
    assertThat(result.questions().get(0).question()).isEqualTo("준비물이 있나요?");
    assertThat(result.questions().get(0).options())
      .extracting(
        RoutineAiPipeline.RoutineQuestionResult.QuestionResultItem.OptionResult::emoji,
        RoutineAiPipeline.RoutineQuestionResult.QuestionResultItem.OptionResult::label
      )
      .containsExactly(tuple("☔", "우산"), tuple("🧥", "우비"), tuple("👖", "장화"));
    assertThat(result.questions().get(1).options())
      .extracting(RoutineAiPipeline.RoutineQuestionResult.QuestionResultItem.OptionResult::label)
      .containsExactly("시간 변경", "장소 변경", "동행자 변경");
  }

  @Test
  @DisplayName("옵션에 label이 없으면 그 옵션만 제외하고 나머지는 유지한다")
  void generateQuestion_optionMissingLabel_dropsOnlyThatOption() {
    String json = "{\"questions\":[{\"supportGoal\":\"PREPARE_ITEMS\",\"question\":\"준비물이 있나요?\","
      + "\"options\":[{\"emoji\":\"☔\",\"label\":\"우산\"},{\"emoji\":\"🧥\",\"label\":\"우비\"},"
      + "{\"emoji\":\"👖\",\"label\":\"장화\"},{\"emoji\":\"🧦\",\"label\":\"\"}]}]}";
    when(geminiTextClient.generateQuestion(any(), any(), any())).thenReturn(textResponse(json));

    RoutineAiPipeline.RoutineQuestionResult result = routineAiPipeline.generateQuestion(
      "하늘이", Set.of(SupportGoal.PREPARE_ITEMS), "내일 비 오는 날"
    );

    assertThat(result.questions()).hasSize(1);
    assertThat(result.questions().get(0).options())
      .extracting(RoutineAiPipeline.RoutineQuestionResult.QuestionResultItem.OptionResult::label)
      .containsExactly("우산", "우비", "장화");
  }

  @Test
  @DisplayName("한 목표의 모든 옵션 label이 비어있으면 그 목표만 fallback으로 대체된다")
  void generateQuestion_oneGoalAllOptionsMissingLabel_fallsBackOnlyThatGoal() {
    String json = "{\"questions\":["
      + "{\"supportGoal\":\"PREPARE_ITEMS\",\"question\":\"준비물이 있나요?\",\"options\":["
      + "{\"emoji\":\"☔\",\"label\":\"\"},{\"emoji\":\"🧥\",\"label\":\"   \"}]},"
      + "{\"supportGoal\":\"PREPARE_NEW\",\"question\":\"평소와 다른 점이 있나요?\",\"options\":["
      + "{\"emoji\":\"⏰\",\"label\":\"시간 변경\"},{\"emoji\":\"📍\",\"label\":\"장소 변경\"},"
      + "{\"emoji\":\"👥\",\"label\":\"동행자 변경\"}]}]}";
    when(geminiTextClient.generateQuestion(any(), any(), any())).thenReturn(textResponse(json));

    RoutineAiPipeline.RoutineQuestionResult result = routineAiPipeline.generateQuestion(
      "하늘이", Set.of(SupportGoal.PREPARE_ITEMS, SupportGoal.PREPARE_NEW), "내일 비 오는 날"
    );

    assertThat(result.questions()).hasSize(2);
    // generateQuestion()이 PREPARE_ITEMS -> PREPARE_NEW 고정 순서로 순회하므로 순서까지 고정된다.
    assertThat(result.questions())
      .extracting(RoutineAiPipeline.RoutineQuestionResult.QuestionResultItem::question)
      .containsExactly("꼭 챙겨야 하는 준비물이 있나요?", "평소와 다른 점이 있나요?");
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
  @DisplayName("Gemini 호출이 실패하면 대체 답변의 모든 옵션에 emoji가 채워지고 직접 입력 항목은 없다")
  void generateQuestion_geminiFails_fallbackHasEmojiAndNoManualInputOption() {
    when(geminiTextClient.generateQuestion(any(), any(), any()))
      .thenThrow(new RuntimeException("Gemini 호출 실패"));

    RoutineAiPipeline.RoutineQuestionResult result = routineAiPipeline.generateQuestion(
      "하늘이", Set.of(SupportGoal.PREPARE_ITEMS, SupportGoal.PREPARE_NEW), "내일 비 오는 날"
    );

    List<RoutineAiPipeline.RoutineQuestionResult.QuestionResultItem.OptionResult> allOptions =
      result.questions().stream().flatMap(item -> item.options().stream()).toList();
    assertThat(allOptions).allSatisfy(option -> assertThat(option.emoji()).isNotBlank());
    assertThat(allOptions)
      .extracting(RoutineAiPipeline.RoutineQuestionResult.QuestionResultItem.OptionResult::label)
      .doesNotContain("직접 입력");
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

  @Test
  @DisplayName("supportGoal이 요청 목표와 다르면 그 항목은 무시하고 해당 목표는 fallback으로 대체된다")
  void generateQuestion_supportGoalMismatch_ignoresAndFallsBack() {
    String json = "{\"questions\":["
      + "{\"supportGoal\":\"PREPARE_NEW\",\"question\":\"준비물이 있나요?\",\"options\":["
      + "{\"emoji\":\"☔\",\"label\":\"우산\"},{\"emoji\":\"🧥\",\"label\":\"우비\"},{\"emoji\":\"👖\",\"label\":\"장화\"}]}]}";
    when(geminiTextClient.generateQuestion(any(), any(), any())).thenReturn(textResponse(json));

    RoutineAiPipeline.RoutineQuestionResult result = routineAiPipeline.generateQuestion(
      "하늘이", Set.of(SupportGoal.PREPARE_ITEMS), "내일 비 오는 날"
    );

    assertThat(result.questions()).hasSize(1);
    assertThat(result.questions().get(0).question()).isEqualTo("꼭 챙겨야 하는 준비물이 있나요?");
  }

  @Test
  @DisplayName("옵션이 3개 미만이면 그 목표는 무효로 판단해 fallback으로 대체된다")
  void generateQuestion_fewerThanThreeOptions_fallsBackThatGoal() {
    String json = "{\"questions\":[{\"supportGoal\":\"PREPARE_ITEMS\",\"question\":\"준비물이 있나요?\","
      + "\"options\":[{\"emoji\":\"☔\",\"label\":\"우산\"},{\"emoji\":\"🧥\",\"label\":\"우비\"}]}]}";
    when(geminiTextClient.generateQuestion(any(), any(), any())).thenReturn(textResponse(json));

    RoutineAiPipeline.RoutineQuestionResult result = routineAiPipeline.generateQuestion(
      "하늘이", Set.of(SupportGoal.PREPARE_ITEMS), "내일 비 오는 날"
    );

    assertThat(result.questions()).hasSize(1);
    assertThat(result.questions().get(0).question()).isEqualTo("꼭 챙겨야 하는 준비물이 있나요?");
  }

  @Test
  @DisplayName("Gemini가 유효한 title/steps를 반환하면 이미지까지 생성해 결과를 만들고, order는 배열 순서로 재정렬된다")
  void generateForCreate_validResponse_returnsGeneratedStepsInArrayOrder() {
    String json = "{\"title\":\"비 오는 날 학교 가기\",\"steps\":["
      + "{\"order\":2,\"title\":\"우산을 챙겨요\",\"description\":\"우산을 챙겨요\"},"
      + "{\"order\":1,\"title\":\"옷을 입어요\",\"description\":\"옷을 입어요\"}]}";
    when(geminiTextClient.generate(any(), any(), any(), any())).thenReturn(textResponse(json));
    when(geminiImageClient.generateImage(any(), any()))
      .thenReturn(new GeminiImageClient.GeneratedImage(new byte[]{1, 2, 3}, "png"));
    when(routineImageStorage.save(any(), any(), any())).thenReturn("data/routine-images/batch/1.png");

    RoutineAiPipeline.RoutineGenerationResult result = routineAiPipeline.generateForCreate(
      "내일 비 오는 날 학교 가기", "하늘이", Set.of(SupportGoal.PREPARE_ITEMS), null, CharacterType.LULU
    );

    assertThat(result.title()).isEqualTo("비 오는 날 학교 가기");
    assertThat(result.steps()).hasSize(2);
    assertThat(result.steps().get(0).order()).isEqualTo(1);
    assertThat(result.steps().get(0).description()).isEqualTo("우산을 챙겨요");
    assertThat(result.steps().get(1).order()).isEqualTo(2);
    assertThat(result.steps().get(1).description()).isEqualTo("옷을 입어요");
    verify(geminiImageClient).generateImage("우산을 챙겨요", CharacterType.LULU);
    verify(geminiImageClient).generateImage("옷을 입어요", CharacterType.LULU);
    assertThat(result.steps().get(0).title()).isEqualTo("우산을 챙겨요");
    assertThat(result.steps().get(1).title()).isEqualTo("옷을 입어요");
  }

  @Test
  @DisplayName("캐릭터를 선택하지 않은 회원이면 이미지 생성 호출에 캐릭터 없이(null) 전달된다")
  void generateForCreate_noCharacter_passesNullCharacterToImageClient() {
    String json = "{\"title\":\"병원 가기\",\"steps\":[{\"order\":1,\"title\":\"옷을 입어요\",\"description\":\"옷을 입어요\"}]}";
    when(geminiTextClient.generate(any(), any(), any(), any())).thenReturn(textResponse(json));
    when(geminiImageClient.generateImage(any(), any()))
      .thenReturn(new GeminiImageClient.GeneratedImage(new byte[]{1, 2, 3}, "png"));
    when(routineImageStorage.save(any(), any(), any())).thenReturn("data/routine-images/batch/1.png");

    routineAiPipeline.generateForCreate("내일 병원 가기", "하늘이", Set.of(), null, null);

    verify(geminiImageClient).generateImage("옷을 입어요", null);
  }

  @Test
  @DisplayName("Gemini가 title 없이 응답하면 ROUTINE_AI_GENERATION_FAILED를 던진다")
  void generateForCreate_missingTitle_throwsGenerationFailed() {
    String json = "{\"steps\":[{\"order\":1,\"description\":\"설명\"}]}";
    when(geminiTextClient.generate(any(), any(), any(), any())).thenReturn(textResponse(json));

    assertThatThrownBy(() ->
      routineAiPipeline.generateForCreate("내일 병원 가기", "하늘이", Set.of(), null, null))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.ROUTINE_AI_GENERATION_FAILED));
  }

  @Test
  @DisplayName("Gemini가 빈 steps를 반환하면 ROUTINE_STEP_LIMIT_EXCEEDED를 던진다")
  void generateForCreate_emptySteps_throwsStepLimitExceeded() {
    String json = "{\"title\":\"제목\",\"steps\":[]}";
    when(geminiTextClient.generate(any(), any(), any(), any())).thenReturn(textResponse(json));

    assertThatThrownBy(() ->
      routineAiPipeline.generateForCreate("내일 병원 가기", "하늘이", Set.of(), null, null))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.ROUTINE_STEP_LIMIT_EXCEEDED));
  }

  @Test
  @DisplayName("이미지 생성이 1차 실패해도 재시도로 성공하면 정상 저장된다")
  void generateForCreate_imageFailsOnce_retriesAndSucceeds() {
    String json = "{\"title\":\"병원 가기\",\"steps\":[{\"order\":1,\"title\":\"옷을 입어요\",\"description\":\"옷을 입어요\"}]}";
    when(geminiTextClient.generate(any(), any(), any(), any())).thenReturn(textResponse(json));
    when(geminiImageClient.generateImage(any(), any()))
      .thenThrow(new RuntimeException("일시적 실패"))
      .thenReturn(new GeminiImageClient.GeneratedImage(new byte[]{1, 2, 3}, "png"));
    when(routineImageStorage.save(any(), any(), any())).thenReturn("data/routine-images/batch/1.png");

    RoutineAiPipeline.RoutineGenerationResult result = routineAiPipeline.generateForCreate(
      "내일 병원 가기", "하늘이", Set.of(), List.of(), null
    );

    assertThat(result.steps()).hasSize(1);
    assertThat(result.steps().get(0).imagePath()).isEqualTo("data/routine-images/batch/1.png");
    verify(geminiImageClient, times(2)).generateImage(any(), any());
  }

  @Test
  @DisplayName("이미지 생성이 재시도까지 실패하면 ROUTINE_AI_GENERATION_FAILED를 던진다")
  void generateForCreate_imageFailsTwice_throwsGenerationFailed() {
    String json = "{\"title\":\"병원 가기\",\"steps\":[{\"order\":1,\"title\":\"옷을 입어요\",\"description\":\"옷을 입어요\"}]}";
    when(geminiTextClient.generate(any(), any(), any(), any())).thenReturn(textResponse(json));
    when(geminiImageClient.generateImage(any(), any())).thenThrow(new RuntimeException("계속 실패"));

    assertThatThrownBy(() -> routineAiPipeline.generateForCreate(
      "내일 병원 가기", "하늘이", Set.of(), List.of(), null
    ))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.ROUTINE_AI_GENERATION_FAILED));
    verify(geminiImageClient, times(2)).generateImage(any(), any());
  }
}
