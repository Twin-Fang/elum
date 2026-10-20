package com.chuseok22.elumserver.routine.infrastructure.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.application.service.CardImageGenerator;
import com.chuseok22.elumserver.ai.application.service.PictogramCatalog;
import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.ai.infrastructure.client.FluxImageClient;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiTextClient;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageGenerationClient;
import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.TextGenerationClient;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.ImageStyle;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.util.Set;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 비 ko 일과의 파이프라인 — 이름 치환과 AI 실패 폴백. 실제 AI 는 부르지 않는다(클라이언트는 목).
 */
@ExtendWith(MockitoExtension.class)
class RoutineAiPipelineLocaleTest {

  @Mock private TextClientRouter textClientRouter;
  @Mock private TextGenerationClient textGenerationClient;
  @Mock private ImageClientRouter imageClientRouter;
  @Mock private ImageGenerationClient imageGenerationClient;
  @Mock private RoutineImageStorage routineImageStorage;
  @Mock private FluxImageClient fluxImageClient;
  @Mock private GeminiTextClient geminiTextClient;

  private RoutineAiPipeline pipeline;

  @BeforeEach
  void setUp() {
    pipeline = new RoutineAiPipeline(
      textClientRouter,
      new CardImageGenerator(imageClientRouter, fluxImageClient, geminiTextClient),
      routineImageStorage, PictogramCatalog.empty());
    lenient().when(imageClientRouter.current()).thenReturn(imageGenerationClient);
    lenient().when(textClientRouter.current()).thenReturn(textGenerationClient);
    AiCallContext.setContentLocale(AppLocale.ES);
  }

  @AfterEach
  void tearDown() {
    AiCallContext.clear();
  }

  @Test
  @DisplayName("es 일과: AI 가 쓴 Elumi 는 제목·카드 글에서 실제 이름으로 바뀌고, 그림 AI 에는 자리표시 문장이 간다")
  void create_restoresNicknameDirectly_butDrawsWithPlaceholder() {
    String json = "{\"title\":\"Elumi va al colegio\",\"steps\":["
      + "{\"order\":1,\"title\":\"Elumi guarda el cepillo\",\"description\":\"Elumi se lava los dientes\"}]}";
    when(textGenerationClient.generateRoutineJson(any(), any(), any(), any(), anyBoolean())).thenReturn(json);
    when(imageGenerationClient.generateCardImage(any(), any())).thenReturn(new GeneratedImage(new byte[]{1}, "png"));
    when(routineImageStorage.save(any(), any(), any())).thenReturn("data/routine-images/batch/1.png");

    RoutineAiPipeline.RoutineGenerationResult result = pipeline.generateForCreate(
      "Haneul va al colegio", "Haneul", Set.of(), null, CharacterType.LULU, ImageStyle.CARTOON, "profile-1");

    assertThat(result.title()).isEqualTo("Haneul va al colegio");
    assertThat(result.steps().get(0).title()).isEqualTo("Haneul guarda el cepillo");
    assertThat(result.steps().get(0).description()).isEqualTo("Haneul se lava los dientes");
    // 이름은 그림 AI 에도 가면 안 된다 — 치환은 그림을 그린 뒤에 한다
    verify(imageGenerationClient).generateCardImage(argThat(scene -> "Elumi se lava los dientes".equals(scene.stepDescription())), eq(CharacterType.LULU));
  }

  @Test
  @DisplayName("es 일과: 그림 AI 가 재시도까지 실패해도 글은 남고 그림만 비는다 (서비스 원칙 6)")
  void create_imageFailureKeepsTheCard() {
    String json = "{\"title\":\"Ir al colegio\",\"steps\":["
      + "{\"order\":1,\"title\":\"Ponte la ropa\",\"description\":\"Ponte la ropa\"}]}";
    when(textGenerationClient.generateRoutineJson(any(), any(), any(), any(), anyBoolean())).thenReturn(json);
    when(imageGenerationClient.generateCardImage(any(), any())).thenThrow(new IllegalStateException("image down"));

    RoutineAiPipeline.RoutineGenerationResult result = pipeline.generateForCreate(
      "Ir al colegio", "Haneul", Set.of(), null, CharacterType.LULU, ImageStyle.CARTOON, "profile-1");

    assertThat(result.steps()).hasSize(1);
    assertThat(result.steps().get(0).title()).isEqualTo("Ponte la ropa");
    assertThat(result.steps().get(0).imagePath()).isNull();
  }

  @Test
  @DisplayName("es 일과: 추가 질문 AI 가 죽어도 목표마다 질문이 나온다 — 폴백 (서비스 원칙 6)")
  void question_aiDown_stillAsksPerGoal() {
    when(textGenerationClient.generateQuestionJson(any(), any(), any())).thenThrow(new IllegalStateException("AI down"));

    RoutineAiPipeline.RoutineQuestionResult result = pipeline.generateQuestion(
      "Haneul", Set.of(SupportGoal.PREPARE_ITEMS, SupportGoal.PREPARE_NEW), "Ir al colegio");

    assertThat(result.questions()).hasSize(2);
    result.questions().forEach(question -> {
      assertThat(question.question()).isNotBlank();
      assertThat(question.options()).hasSizeGreaterThanOrEqualTo(3);
    });
  }

  @Test
  @DisplayName("es 일과: 질문·선택지의 Elumi 도 실제 이름으로 바뀐다")
  void question_restoresNickname() {
    String json = "{\"questions\":[{\"supportGoal\":\"PREPARE_ITEMS\",\"question\":\"¿Qué necesita Elumi?\","
      + "\"options\":[{\"emoji\":\"☔\",\"label\":\"paraguas de Elumi\"},{\"emoji\":\"🎒\",\"label\":\"mochila\"},"
      + "{\"emoji\":\"💧\",\"label\":\"botella\"}]}]}";
    when(textGenerationClient.generateQuestionJson(any(), any(), any())).thenReturn(json);

    RoutineAiPipeline.RoutineQuestionResult result = pipeline.generateQuestion(
      "Haneul", Set.of(SupportGoal.PREPARE_ITEMS), "Ir al colegio");

    assertThat(result.questions().get(0).question()).isEqualTo("¿Qué necesita Haneul?");
    assertThat(result.questions().get(0).options().get(0).label()).isEqualTo("paraguas de Haneul");
  }
}
