package com.chuseok22.elumserver.routine.infrastructure.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.core.RoutineTranslationDraft;
import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.TextGenerationClient;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/// 일과 번역 응답 검증 (#1077): 단계 수가 다르면 실패, 이름은 AI 에 안 나가고 되돌아옴, 지어낸 보상은 버림
class RoutineTranslationAiTest {

  private final TextClientRouter textClientRouter = mock(TextClientRouter.class);
  private final TextGenerationClient textClient = mock(TextGenerationClient.class);
  private final RoutineTranslationAi translationAi = new RoutineTranslationAi(textClientRouter);

  private static final RoutineTranslationDraft SOURCE = new RoutineTranslationDraft("하늘이 아침 준비", null, List.of(
    new RoutineTranslationDraft.StepText("양치하기", "하늘이가 이를 닦아요"),
    new RoutineTranslationDraft.StepText("옷 입기", "옷을 입어요")));

  @BeforeEach
  void setUp() {
    when(textClientRouter.current()).thenReturn(textClient);
  }

  @Test
  @DisplayName("응답 카드 수가 원문과 다르면 ROUTINE_TRANSLATE_FAILED — 받아들이면 카드 그림과 글이 어긋난다")
  void stepCountMismatch_fails() {
    when(textClient.translateRoutineJson(any(), eq(AppLocale.KO), eq(AppLocale.EN)))
      .thenReturn("{\"title\":\"Morning\",\"rewardText\":null,\"steps\":[{\"title\":\"Brush\",\"description\":\"Brush teeth\"}]}");

    assertThatThrownBy(() -> translationAi.translate(SOURCE, "하늘", AppLocale.KO, AppLocale.EN))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_TRANSLATE_FAILED);
  }

  @Test
  @DisplayName("이룸이 이름은 자리표시로 나가고 응답 자리표시는 이름으로 돌아온다 / 원문에 없던 보상은 버린다")
  void nicknameIsMaskedAndRestored_inventedRewardDropped() {
    ArgumentCaptor<RoutineTranslationDraft> sent = ArgumentCaptor.forClass(RoutineTranslationDraft.class);
    when(textClient.translateRoutineJson(sent.capture(), eq(AppLocale.KO), eq(AppLocale.EN)))
      .thenReturn("{\"title\":\"Elumi's morning\",\"rewardText\":\"Candy\",\"steps\":["
        + "{\"title\":\"Brush\",\"description\":\"Elumi brushes teeth\"},"
        + "{\"title\":\"Dress\",\"description\":\"Put on clothes\"}]}");

    RoutineTranslationDraft translated = translationAi.translate(SOURCE, "하늘", AppLocale.KO, AppLocale.EN);

    assertThat(sent.getValue().title()).doesNotContain("하늘");
    assertThat(sent.getValue().steps().get(0).description()).doesNotContain("하늘");
    assertThat(translated.title()).isEqualTo("하늘's morning");
    assertThat(translated.steps()).extracting(RoutineTranslationDraft.StepText::description)
      .containsExactly("하늘 brushes teeth", "Put on clothes");
    assertThat(translated.rewardText()).isNull();
  }

  @Test
  @DisplayName("한국어로 바꾼 일과는 AI 가 틀린 목적격 조사를 바로잡는다 (#1190)")
  void translatedToKorean_fixesObjectParticle() {
    RoutineTranslationDraft english = new RoutineTranslationDraft("Wash hands", null, List.of(
      new RoutineTranslationDraft.StepText("Turn off", "Turn off the tap")));
    when(textClient.translateRoutineJson(any(), eq(AppLocale.EN), eq(AppLocale.KO)))
      .thenReturn("{\"title\":\"손 씻기\",\"rewardText\":null,\"steps\":["
        + "{\"title\":\"수도꼭지을 닫아요\",\"description\":\"수도꼭지을 닫아요\"}]}");

    RoutineTranslationDraft translated = translationAi.translate(english, "하늘", AppLocale.EN, AppLocale.KO);

    assertThat(translated.steps().get(0).description()).isEqualTo("수도꼭지를 닫아요");
  }
}
