package com.chuseok22.elumserver.routine.infrastructure.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.tuple;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anySet;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.application.service.CardImageGenerator;
import com.chuseok22.elumserver.ai.application.service.PictogramCatalog;
import com.chuseok22.elumserver.ai.core.FluxSeed;
import com.chuseok22.elumserver.ai.core.ImageProvider;
import com.chuseok22.elumserver.ai.infrastructure.client.FluxImageClient;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiTextClient;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;

import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageGenerationClient;
import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.TextGenerationClient;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.ImageStyle;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class RoutineAiPipelineTest {

  @Mock
  private TextClientRouter textClientRouter;

  @Mock
  private TextGenerationClient textGenerationClient;

  @Mock
  private ImageClientRouter imageClientRouter;

  @Mock
  private ImageGenerationClient imageGenerationClient;

  @Mock
  private RoutineImageStorage routineImageStorage;

  @Mock
  private FluxImageClient fluxImageClient;

  @Mock
  private GeminiTextClient geminiTextClient;

  private RoutineAiPipeline routineAiPipeline;


  @BeforeEach
  void setUp() {
    // 제공자 고르기는 실제 CardImageGenerator 로 돈다. 가짜 라우터의 selected() 는 null 이라
    // FLUX 가 아니고, 지금처럼 current() 의 제공자로 그린다.
    routineAiPipeline = new RoutineAiPipeline(
      textClientRouter, imageClientRouter,
      new CardImageGenerator(imageClientRouter, fluxImageClient, geminiTextClient),
      routineImageStorage, PictogramCatalog.empty());
    lenient().when(imageClientRouter.current()).thenReturn(imageGenerationClient);
    lenient().when(textClientRouter.current()).thenReturn(textGenerationClient);
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
    when(textGenerationClient.generateQuestionJson(eq("하늘이"), anySet(), eq("내일 비 오는 날")))
      .thenReturn(json);

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
    when(textGenerationClient.generateQuestionJson(any(), any(), any())).thenReturn(json);

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
    when(textGenerationClient.generateQuestionJson(any(), any(), any())).thenReturn(json);

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
    when(textGenerationClient.generateQuestionJson(any(), any(), any()))
      .thenThrow(new RuntimeException("Gemini 호출 실패"));

    RoutineAiPipeline.RoutineQuestionResult result = routineAiPipeline.generateQuestion(
      "하늘이", Set.of(SupportGoal.PREPARE_ITEMS, SupportGoal.PREPARE_NEW), "내일 비 오는 날"
    );

    assertThat(result.questions()).hasSize(2);
  }

  @Test
  @DisplayName("Gemini 호출이 실패하면 대체 답변의 모든 옵션에 emoji가 채워지고 직접 입력 항목은 없다")
  void generateQuestion_geminiFails_fallbackHasEmojiAndNoManualInputOption() {
    when(textGenerationClient.generateQuestionJson(any(), any(), any()))
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
    when(textGenerationClient.generateQuestionJson(any(), any(), any()))
      .thenReturn("{\"questions\":[]}");

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
    when(textGenerationClient.generateQuestionJson(any(), any(), any())).thenReturn(json);

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
    when(textGenerationClient.generateQuestionJson(any(), any(), any())).thenReturn(json);

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
    when(textGenerationClient.generateRoutineJson(any(), any(), any(), any(), anyBoolean())).thenReturn(json);
    when(imageGenerationClient.generateImage(any(), any()))
      .thenReturn(new GeneratedImage(new byte[]{1, 2, 3}, "png"));
    when(routineImageStorage.save(any(), any(), any())).thenReturn("data/routine-images/batch/1.png");

    RoutineAiPipeline.RoutineGenerationResult result = routineAiPipeline.generateForCreate(
      "내일 비 오는 날 학교 가기", "하늘이", Set.of(SupportGoal.PREPARE_ITEMS), null, CharacterType.LULU, ImageStyle.CARTOON, "profile-1"
    );

    assertThat(result.title()).isEqualTo("비 오는 날 학교 가기");
    assertThat(result.steps()).hasSize(2);
    assertThat(result.steps().get(0).order()).isEqualTo(1);
    assertThat(result.steps().get(0).description()).isEqualTo("우산을 챙겨요");
    assertThat(result.steps().get(1).order()).isEqualTo(2);
    assertThat(result.steps().get(1).description()).isEqualTo("옷을 입어요");
    verify(imageGenerationClient).generateImage("우산을 챙겨요", CharacterType.LULU);
    verify(imageGenerationClient).generateImage("옷을 입어요", CharacterType.LULU);
    assertThat(result.steps().get(0).title()).isEqualTo("우산을 챙겨요");
    assertThat(result.steps().get(1).title()).isEqualTo("옷을 입어요");
  }

  @Test
  @DisplayName("AI 가 쓴 이룸이는 제목·카드 제목·설명에서 실제 이름으로 바뀌고 조사도 맞춰진다. 그림은 자리표시 문장으로 그린다 (#374)")
  void generateForCreate_restoresNicknameInTextButDrawsWithPlaceholder() {
    String json = "{\"title\":\"이룸이가 치과에 가요\",\"steps\":["
      + "{\"order\":1,\"title\":\"이룸이는 칫솔을 챙겨요\",\"description\":\"이룸이와 함께 가요\"}]}";
    when(textGenerationClient.generateRoutineJson(any(), any(), any(), any(), anyBoolean())).thenReturn(json);
    when(imageGenerationClient.generateImage(any(), any()))
      .thenReturn(new GeneratedImage(new byte[]{1}, "png"));
    when(routineImageStorage.save(any(), any(), any())).thenReturn("data/routine-images/batch/1.png");

    RoutineAiPipeline.RoutineGenerationResult result = routineAiPipeline.generateForCreate(
      "치과 가기", "하늘", Set.of(), null, CharacterType.LULU, ImageStyle.CARTOON, "profile-1"
    );

    assertThat(result.title()).isEqualTo("하늘이 치과에 가요");
    assertThat(result.steps().get(0).title()).isEqualTo("하늘은 칫솔을 챙겨요");
    assertThat(result.steps().get(0).description()).isEqualTo("하늘과 함께 가요");
    // 이름은 그림 AI(OpenAI·FLUX)에도 가면 안 된다 — 치환은 그림을 그린 뒤에 한다
    verify(imageGenerationClient).generateImage("이룸이와 함께 가요", CharacterType.LULU);
  }

  @Test
  @DisplayName("이름이 비어 있으면 AI 가 쓴 이룸이를 그대로 둔다 (#374 E1)")
  void generateForCreate_blankNickname_keepsPlaceholder() {
    String json = "{\"title\":\"이룸이가 치과에 가요\",\"steps\":["
      + "{\"order\":1,\"title\":\"칫솔을 챙겨요\",\"description\":\"칫솔을 챙겨요\"}]}";
    when(textGenerationClient.generateRoutineJson(any(), any(), any(), any(), anyBoolean())).thenReturn(json);
    when(imageGenerationClient.generateImage(any(), any()))
      .thenReturn(new GeneratedImage(new byte[]{1}, "png"));
    when(routineImageStorage.save(any(), any(), any())).thenReturn("data/routine-images/batch/1.png");

    RoutineAiPipeline.RoutineGenerationResult result = routineAiPipeline.generateForCreate(
      "치과 가기", " ", Set.of(), null, CharacterType.LULU, ImageStyle.CARTOON, "profile-1"
    );

    assertThat(result.title()).isEqualTo("이룸이가 치과에 가요");
  }

  @Test
  @DisplayName("추가 질문의 질문 문장과 선택지에 든 이룸이도 실제 이름으로 바뀐다 (#374 E8)")
  void generateQuestion_restoresNicknameInQuestionAndOptions() {
    String json = "{\"questions\":[{\"supportGoal\":\"PREPARE_ITEMS\",\"question\":\"이룸이가 혼자 잠들 때 챙겨야 할 물건이 있나요?\","
      + "\"options\":[{\"emoji\":\"🧸\",\"label\":\"이룸이의 인형\"},{\"emoji\":\"💡\",\"label\":\"무드등\"},"
      + "{\"emoji\":\"🛏️\",\"label\":\"이불\"}]}]}";
    when(textGenerationClient.generateQuestionJson(any(), any(), any())).thenReturn(json);

    RoutineAiPipeline.RoutineQuestionResult result = routineAiPipeline.generateQuestion(
      "하늘", Set.of(SupportGoal.PREPARE_ITEMS), "잠자기"
    );

    assertThat(result.questions().get(0).question()).isEqualTo("하늘이 혼자 잠들 때 챙겨야 할 물건이 있나요?");
    assertThat(result.questions().get(0).options())
      .extracting(RoutineAiPipeline.RoutineQuestionResult.QuestionResultItem.OptionResult::label)
      .containsExactly("하늘의 인형", "무드등", "이불");
  }

  @Test
  @DisplayName("캐릭터를 선택하지 않은 회원이면 이미지 생성 호출에 캐릭터 없이(null) 전달된다")
  void generateForCreate_noCharacter_passesNullCharacterToImageClient() {
    String json = "{\"title\":\"병원 가기\",\"steps\":[{\"order\":1,\"title\":\"옷을 입어요\",\"description\":\"옷을 입어요\"}]}";
    when(textGenerationClient.generateRoutineJson(any(), any(), any(), any(), anyBoolean())).thenReturn(json);
    when(imageGenerationClient.generateImage(any(), any()))
      .thenReturn(new GeneratedImage(new byte[]{1, 2, 3}, "png"));
    when(routineImageStorage.save(any(), any(), any())).thenReturn("data/routine-images/batch/1.png");

    routineAiPipeline.generateForCreate("내일 병원 가기", "하늘이", Set.of(), null, null, ImageStyle.CARTOON, "profile-1");

    verify(imageGenerationClient).generateImage("옷을 입어요", null);
  }

  @Test
  @DisplayName("Gemini가 title 없이 응답하면 ROUTINE_AI_GENERATION_FAILED를 던진다")
  void generateForCreate_missingTitle_throwsGenerationFailed() {
    String json = "{\"steps\":[{\"order\":1,\"description\":\"설명\"}]}";
    when(textGenerationClient.generateRoutineJson(any(), any(), any(), any(), anyBoolean())).thenReturn(json);

    assertThatThrownBy(() ->
      routineAiPipeline.generateForCreate("내일 병원 가기", "하늘이", Set.of(), null, null, ImageStyle.CARTOON, "profile-1"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.ROUTINE_AI_GENERATION_FAILED));
  }

  @Test
  @DisplayName("Gemini가 빈 steps를 반환하면 ROUTINE_STEP_LIMIT_EXCEEDED를 던진다")
  void generateForCreate_emptySteps_throwsStepLimitExceeded() {
    String json = "{\"title\":\"제목\",\"steps\":[]}";
    when(textGenerationClient.generateRoutineJson(any(), any(), any(), any(), anyBoolean())).thenReturn(json);

    assertThatThrownBy(() ->
      routineAiPipeline.generateForCreate("내일 병원 가기", "하늘이", Set.of(), null, null, ImageStyle.CARTOON, "profile-1"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.ROUTINE_STEP_LIMIT_EXCEEDED));
  }

  @Test
  @DisplayName("이미지 생성이 1차 실패해도 재시도로 성공하면 정상 저장된다")
  void generateForCreate_imageFailsOnce_retriesAndSucceeds() {
    String json = "{\"title\":\"병원 가기\",\"steps\":[{\"order\":1,\"title\":\"옷을 입어요\",\"description\":\"옷을 입어요\"}]}";
    when(textGenerationClient.generateRoutineJson(any(), any(), any(), any(), anyBoolean())).thenReturn(json);
    when(imageGenerationClient.generateImage(any(), any()))
      .thenThrow(new RuntimeException("일시적 실패"))
      .thenReturn(new GeneratedImage(new byte[]{1, 2, 3}, "png"));
    when(routineImageStorage.save(any(), any(), any())).thenReturn("data/routine-images/batch/1.png");

    RoutineAiPipeline.RoutineGenerationResult result = routineAiPipeline.generateForCreate(
      "내일 병원 가기", "하늘이", Set.of(), List.of(), null, ImageStyle.CARTOON, "profile-1"
    );

    assertThat(result.steps()).hasSize(1);
    assertThat(result.steps().get(0).imagePath()).isEqualTo("data/routine-images/batch/1.png");
    verify(imageGenerationClient, times(2)).generateImage(any(), any());
  }

  @Test
  @DisplayName("이미지 생성이 재시도까지 실패해도 일과는 이미지 없이(imagePath=null) 저장된다")
  void generateForCreate_imageFailsTwice_savesWithoutImage() {
    // 이미지 하나가 끝까지 실패해도 일과 전체를 포기하지 않는다(서비스 원칙 6). 예외를 던지면
    // create()가 500으로 죽어 일과가 서버에 저장조차 안 되던 버그의 근본 원인이었다.
    String json = "{\"title\":\"병원 가기\",\"steps\":[{\"order\":1,\"title\":\"옷을 입어요\",\"description\":\"옷을 입어요\"}]}";
    when(textGenerationClient.generateRoutineJson(any(), any(), any(), any(), anyBoolean())).thenReturn(json);
    when(imageGenerationClient.generateImage(any(), any())).thenThrow(new RuntimeException("계속 실패"));

    RoutineAiPipeline.RoutineGenerationResult result = routineAiPipeline.generateForCreate(
      "내일 병원 가기", "하늘이", Set.of(), List.of(), null, ImageStyle.CARTOON, "profile-1"
    );

    assertThat(result.steps()).hasSize(1);
    assertThat(result.steps().get(0).imagePath()).isNull();
    // 이미지가 없으므로 저장은 아예 호출되지 않는다.
    verify(routineImageStorage, never()).save(any(), any(), any());
    verify(imageGenerationClient, times(2)).generateImage(any(), any());
  }

  @Test
  @DisplayName("FLUX 를 고르면 같은 글 호출에서 카드마다 영어 장면을 받아 그대로 FLUX 에 넘긴다 — seed 는 이 일과로 고정 (#373)")
  void generateForCreate_flux_passesEnglishSceneAndRoutineSeed() {
    when(imageClientRouter.selected()).thenReturn(ImageProvider.FLUX);
    when(fluxImageClient.available()).thenReturn(true);
    String json = "{\"title\":\"비 오는 날 학교에 가요\",\"steps\":["
      + "{\"order\":1,\"title\":\"우산을 챙겨요\",\"description\":\"우산을 챙겨요\","
      + "\"imagePromptEn\":\"The character picks up a closed red umbrella.\"}]}";
    when(textGenerationClient.generateRoutineJson(any(), any(), any(), any(), eq(true))).thenReturn(json);
    when(fluxImageClient.generate(any(), any(), any())).thenReturn(new GeneratedImage(new byte[]{1}, "jpg"));
    when(routineImageStorage.save(any(), any(), any())).thenReturn("data/routine-images/batch/1.jpg");

    routineAiPipeline.generateForCreate("비 오는 날 학교", "하늘이", Set.of(), null, CharacterType.LULU, ImageStyle.CARTOON, "profile-1");

    verify(fluxImageClient).generate(
      "The character picks up a closed red umbrella.", CharacterType.LULU,
      FluxSeed.of(FluxSeed.routineKey("profile-1", "비 오는 날 학교에 가요")));
    verify(geminiTextClient, never()).translateImagePrompt(any());
  }

  @Test
  @DisplayName("FLUX 가 아니면 영어 장면을 달라고 하지 않는다 — 쓰지도 않을 출력 토큰 (#375)")
  void generateForCreate_notFlux_doesNotAskEnglishScene() {
    String json = "{\"title\":\"병원 가기\",\"steps\":[{\"order\":1,\"title\":\"옷을 입어요\",\"description\":\"옷을 입어요\"}]}";
    when(textGenerationClient.generateRoutineJson(any(), any(), any(), any(), eq(false))).thenReturn(json);
    when(imageGenerationClient.generateImage(any(), any())).thenReturn(new GeneratedImage(new byte[]{1}, "png"));
    when(routineImageStorage.save(any(), any(), any())).thenReturn("data/routine-images/batch/1.png");

    routineAiPipeline.generateForCreate("내일 병원 가기", "하늘이", Set.of(), null, null, ImageStyle.CARTOON, "profile-1");

    verify(textGenerationClient).generateRoutineJson(any(), any(), any(), any(), eq(false));
  }


  // ── 그림 방식 (#457) ────────────────────────────────────────────────

  private static final String ONE_STEP_JSON =
    "{\"title\":\"병원 가기\",\"steps\":[{\"order\":1,\"title\":\"옷을 입어요\",\"description\":\"옷을 입어요\"}]}";

  @Test
  @DisplayName("직접 사진이면 그림 호출을 하지 않고 imagePath 는 null — 카드 글은 그대로 만든다")
  void generateForCreate_photoOnly_skipsImageButKeepsText() {
    when(textGenerationClient.generateRoutineJson(any(), any(), any(), any(), anyBoolean())).thenReturn(ONE_STEP_JSON);

    RoutineAiPipeline.RoutineGenerationResult result = routineAiPipeline.generateForCreate(
      "내일 병원 가기", "하늘이", Set.of(), List.of(), CharacterType.LULU, ImageStyle.PHOTO_ONLY, "profile-1");

    assertThat(result.title()).isEqualTo("병원 가기");
    assertThat(result.steps()).hasSize(1);
    assertThat(result.steps().get(0).title()).isEqualTo("옷을 입어요");
    assertThat(result.steps().get(0).imagePath()).isNull();
    org.mockito.Mockito.verifyNoInteractions(imageGenerationClient, fluxImageClient, geminiTextClient, routineImageStorage);
  }

  @Test
  @DisplayName("직접 사진은 FLUX 를 골라 둬도 영어 장면을 요청하지 않는다 — 쓰지 않을 출력 토큰")
  void generateForCreate_photoOnly_doesNotAskForEnglishScene() {
    when(imageClientRouter.selected()).thenReturn(ImageProvider.FLUX);
    when(textGenerationClient.generateRoutineJson(any(), any(), any(), any(), anyBoolean())).thenReturn(ONE_STEP_JSON);

    routineAiPipeline.generateForCreate(
      "내일 병원 가기", "하늘이", Set.of(), List.of(), CharacterType.LULU, ImageStyle.PHOTO_ONLY, "profile-1");

    verify(textGenerationClient).generateRoutineJson(any(), any(), any(), any(), eq(false));
  }

  @Test
  @DisplayName("만화 + FLUX 는 영어 장면을 요청한다 — 기존 동작 그대로")
  void generateForCreate_cartoonFlux_asksForEnglishScene() {
    when(imageClientRouter.selected()).thenReturn(ImageProvider.FLUX);
    when(textGenerationClient.generateRoutineJson(any(), any(), any(), any(), anyBoolean())).thenReturn(ONE_STEP_JSON);
    when(fluxImageClient.available()).thenReturn(false);
    when(imageClientRouter.of(ImageProvider.OPENAI)).thenReturn(java.util.Optional.of(imageGenerationClient));
    when(imageGenerationClient.available()).thenReturn(true);
    when(imageGenerationClient.generateImage(any(), any())).thenReturn(new GeneratedImage(new byte[]{1}, "png"));
    when(routineImageStorage.save(any(), any(), any())).thenReturn("data/routine-images/batch/1.png");

    routineAiPipeline.generateForCreate(
      "내일 병원 가기", "하늘이", Set.of(), List.of(), CharacterType.LULU, ImageStyle.CARTOON, "profile-1");

    verify(textGenerationClient).generateRoutineJson(any(), any(), any(), any(), eq(true));
  }

  @Test
  @DisplayName("실사면 캐릭터 없는 실사 호출로 그리고 만화 호출은 하지 않는다")
  void generateForCreate_realistic_usesRealisticImageCall() {
    when(textGenerationClient.generateRoutineJson(any(), any(), any(), any(), anyBoolean())).thenReturn(ONE_STEP_JSON);
    when(imageGenerationClient.generateRealisticImage("옷을 입어요"))
      .thenReturn(new GeneratedImage(new byte[]{1}, "png"));
    when(routineImageStorage.save(any(), any(), any())).thenReturn("data/routine-images/batch/1.png");

    RoutineAiPipeline.RoutineGenerationResult result = routineAiPipeline.generateForCreate(
      "내일 병원 가기", "하늘이", Set.of(), List.of(), CharacterType.LULU, ImageStyle.REALISTIC, "profile-1");

    assertThat(result.steps().get(0).imagePath()).isEqualTo("data/routine-images/batch/1.png");
    verify(imageGenerationClient, never()).generateImage(any(), any());
  }

  // ── 무료 픽토그램 (#247) ────────────────────────────────────────────

  private static final String FALLBACK_ID = "go_,_to";

  private RoutineAiPipeline pipelineWith(PictogramCatalog catalog) {
    return new RoutineAiPipeline(
      textClientRouter, imageClientRouter,
      new CardImageGenerator(imageClientRouter, fluxImageClient, geminiTextClient),
      routineImageStorage, catalog);
  }

  private final PictogramCatalog catalog =
    new PictogramCatalog(List.of("brush_teeth", "get_dressed_,_to", FALLBACK_ID), FALLBACK_ID);

  private List<RoutineAiPipeline.GeneratedStep> createPhotoOnly(RoutineAiPipeline pipeline, String stepsJson) {
    when(textGenerationClient.generateRoutineJson(any(), any(), any(), any(), anyBoolean()))
      .thenReturn("{\"title\":\"아침\",\"steps\":[" + stepsJson + "]}");
    return pipeline.generateForCreate(
      "아침 준비", "하늘이", Set.of(), List.of(), CharacterType.LULU, ImageStyle.PHOTO_ONLY, "profile-1").steps();
  }

  @Test
  @DisplayName("모델이 카탈로그의 id 를 고르면 그대로 카드에 실린다")
  void pictogram_validIdIsKept() {
    var steps = createPhotoOnly(pipelineWith(catalog),
      "{\"order\":1,\"title\":\"양치해요\",\"description\":\"a\",\"pictogramId\":\"brush_teeth\"}");

    assertThat(steps.get(0).pictogramId()).isEqualTo("brush_teeth");
  }

  @Test
  @DisplayName("카탈로그에 없는 id(환각)는 그대로 저장하지 않고 폴백 id 로 바꾼다")
  void pictogram_invalidIdBecomesFallback() {
    var steps = createPhotoOnly(pipelineWith(catalog),
      "{\"order\":1,\"title\":\"양치해요\",\"description\":\"a\",\"pictogramId\":\"teleport_to_moon\"}");

    assertThat(steps.get(0).pictogramId()).isEqualTo(FALLBACK_ID);
  }

  @Test
  @DisplayName("null 이거나 필드가 빠져도(옛 프롬프트·모델) 카드 생성은 성공하고 폴백 id 가 붙는다")
  void pictogram_nullOrMissingBecomesFallback() {
    var steps = createPhotoOnly(pipelineWith(catalog),
      "{\"order\":1,\"title\":\"a\",\"description\":\"a\",\"pictogramId\":null},"
        + "{\"order\":2,\"title\":\"b\",\"description\":\"b\"}");

    assertThat(steps).extracting(RoutineAiPipeline.GeneratedStep::pictogramId).containsExactly(FALLBACK_ID, FALLBACK_ID);
  }

  @Test
  @DisplayName("직접 사진(그림 호출 없음)이어도 pictogramId 를 저장한다 — 그림 방식과 무관")
  void pictogram_savedEvenWhenPhotoOnly() {
    var steps = createPhotoOnly(pipelineWith(catalog),
      "{\"order\":1,\"title\":\"양치해요\",\"description\":\"a\",\"pictogramId\":\"get_dressed_,_to\"}");

    assertThat(steps.get(0).imagePath()).isNull();
    assertThat(steps.get(0).pictogramId()).isEqualTo("get_dressed_,_to");
  }

  @Test
  @DisplayName("AI 그림이 실패해도(재시도까지) pictogramId 는 남는다 — 앱이 픽토그램으로 대체한다")
  void pictogram_savedWhenImageFails() {
    when(textGenerationClient.generateRoutineJson(any(), any(), any(), any(), anyBoolean())).thenReturn(
      "{\"title\":\"아침\",\"steps\":[{\"order\":1,\"title\":\"양치해요\",\"description\":\"a\","
        + "\"pictogramId\":\"brush_teeth\"}]}");
    when(imageGenerationClient.generateImage(any(), any())).thenThrow(new IllegalStateException("이미지 실패"));

    var steps = pipelineWith(catalog).generateForCreate(
      "아침 준비", "하늘이", Set.of(), List.of(), CharacterType.LULU, ImageStyle.CARTOON, "profile-1").steps();

    assertThat(steps.get(0).imagePath()).isNull();
    assertThat(steps.get(0).pictogramId()).isEqualTo("brush_teeth");
  }

  @Test
  @DisplayName("카탈로그를 못 읽은 서버는 pictogramId 가 항상 null 이고 카드 생성은 성공한다")
  void pictogram_emptyCatalogGivesNull() {
    var steps = createPhotoOnly(pipelineWith(PictogramCatalog.empty()),
      "{\"order\":1,\"title\":\"양치해요\",\"description\":\"a\",\"pictogramId\":\"brush_teeth\"}");

    assertThat(steps).hasSize(1);
    assertThat(steps.get(0).pictogramId()).isNull();
  }
}
