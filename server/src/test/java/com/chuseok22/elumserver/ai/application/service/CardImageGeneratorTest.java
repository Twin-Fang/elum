package com.chuseok22.elumserver.ai.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.core.FluxSeed;
import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.ai.core.ImageProvider;
import com.chuseok22.elumserver.ai.infrastructure.client.FluxImageClient;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiTextClient;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageGenerationClient;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.ImageStyle;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.web.client.HttpClientErrorException;

/**
 * 카드 그림 한 장을 어느 제공자로 그릴지 (#373).
 *
 * <p>FLUX 를 고른 때만 영어 장면이 필요하고, FLUX 쪽 무엇이 실패해도 <b>그 카드만</b> OpenAI 로
 * 그린다. 다른 제공자를 고른 때는 지금과 똑같다. 실제 AI 는 부르지 않는다.
 */
@ExtendWith(MockitoExtension.class)
class CardImageGeneratorTest {

  private static final GeneratedImage FLUX_IMAGE = new GeneratedImage(new byte[]{1}, "jpg");
  private static final GeneratedImage OPENAI_IMAGE = new GeneratedImage(new byte[]{2}, "png");
  private static final String SEED_KEY = FluxSeed.routineKey("profile-1", "비 오는 날 학교에 가요");

  @Mock private ImageClientRouter imageClientRouter;
  @Mock private FluxImageClient fluxImageClient;
  @Mock private ImageGenerationClient openAiClient;
  @Mock private GeminiTextClient translator;

  private CardImageGenerator generator;

  @BeforeEach
  void setUp() {
    generator = new CardImageGenerator(imageClientRouter, fluxImageClient, translator);
    lenient().when(imageClientRouter.selected()).thenReturn(ImageProvider.FLUX);
    lenient().when(fluxImageClient.available()).thenReturn(true);
    lenient().when(imageClientRouter.of(ImageProvider.OPENAI)).thenReturn(Optional.of(openAiClient));
    lenient().when(openAiClient.available()).thenReturn(true);
    lenient().when(openAiClient.generateCardImage(any(), any())).thenReturn(OPENAI_IMAGE);
  }

  private CardImageGenerator.CardImageRequest request(String imagePromptEn) {
    return new CardImageGenerator.CardImageRequest("우산을 챙겨요", imagePromptEn, CharacterType.LULU, SEED_KEY, ImageStyle.CARTOON);
  }

  @Test
  @DisplayName("FLUX 가 아니면 지금과 똑같다 — 고른 제공자에 한국어 설명 그대로, 번역도 FLUX 도 안 부른다")
  void otherProvider_unchanged() {
    when(imageClientRouter.selected()).thenReturn(ImageProvider.OPENAI);
    when(imageClientRouter.current()).thenReturn(openAiClient);

    GeneratedImage image = generator.generate(request("The character picks up a red umbrella."));

    assertThat(image).isSameAs(OPENAI_IMAGE);
    verify(openAiClient).generateCardImage(argThat(scene -> "우산을 챙겨요".equals(scene.stepDescription())), eq(CharacterType.LULU));
    verifyNoInteractions(fluxImageClient, translator);
  }

  private static RuntimeException safetyRejected() {
    return new RuntimeException("400 Bad Request: Your request was rejected by the safety system. safety_violations=[self-harm].");
  }

  private CardImageGenerator.CardImageRequest requestWithTitle(String stepTitle) {
    return new CardImageGenerator.CardImageRequest(
      "귀에 체온계를 대요", "The character holds a thermometer near the ear.", CharacterType.LULU, SEED_KEY,
      ImageStyle.CARTOON, "병원에 가요", stepTitle);
  }

  @Test
  @DisplayName("안전 거절이면 장면 문장을 빼고 카드 제목만으로 한 번 더 시도해 그림을 얻는다 (#895)")
  void safetyRejection_retriesWithTitleOnly() {
    when(imageClientRouter.selected()).thenReturn(ImageProvider.OPENAI);
    when(imageClientRouter.current()).thenReturn(openAiClient);
    when(openAiClient.generateCardImage(argThat(scene -> scene != null && "귀에 체온계를 대요".equals(scene.stepDescription())), any()))
      .thenThrow(safetyRejected());
    when(openAiClient.generateCardImage(argThat(scene -> scene != null && "체온을 재요".equals(scene.stepDescription())
      && scene.sceneDetail() == null), any())).thenReturn(OPENAI_IMAGE);

    GeneratedImage image = generator.generate(requestWithTitle("체온을 재요"));

    assertThat(image).isSameAs(OPENAI_IMAGE);
  }

  @Test
  @DisplayName("제목으로 다시 시도해도 거절이면 그대로 던진다 — 부르는 쪽이 기본 그림으로 대체 (#895)")
  void safetyRejection_retryAlsoRejected_throws() {
    when(imageClientRouter.selected()).thenReturn(ImageProvider.OPENAI);
    when(imageClientRouter.current()).thenReturn(openAiClient);
    when(openAiClient.generateCardImage(any(), any())).thenThrow(safetyRejected());

    assertThatThrownBy(() -> generator.generate(requestWithTitle("체온을 재요")))
      .hasMessageContaining("safety system");
    verify(openAiClient, org.mockito.Mockito.times(2)).generateCardImage(any(), any());
  }

  @Test
  @DisplayName("제목이 없는 카드(직접 추가)는 안전 거절을 다시 시도하지 않는다 — 바꿀 문장이 없다 (#895)")
  void safetyRejection_withoutTitle_doesNotRetry() {
    when(imageClientRouter.selected()).thenReturn(ImageProvider.OPENAI);
    when(imageClientRouter.current()).thenReturn(openAiClient);
    when(openAiClient.generateCardImage(any(), any())).thenThrow(safetyRejected());

    assertThatThrownBy(() -> generator.generate(request(null))).hasMessageContaining("safety system");
    verify(openAiClient, org.mockito.Mockito.times(1)).generateCardImage(any(), any());
  }

  @Test
  @DisplayName("안전 거절이 아닌 오류는 이 단계에서 다시 시도하지 않는다 (429 는 호출부 대기 로직 몫) (#895)")
  void otherError_doesNotRetryHere() {
    when(imageClientRouter.selected()).thenReturn(ImageProvider.OPENAI);
    when(imageClientRouter.current()).thenReturn(openAiClient);
    when(openAiClient.generateCardImage(any(), any())).thenThrow(new RuntimeException("429 Too Many Requests"));

    assertThatThrownBy(() -> generator.generate(requestWithTitle("체온을 재요"))).hasMessageContaining("429");
    verify(openAiClient, org.mockito.Mockito.times(1)).generateCardImage(any(), any());
  }

  @Test
  @DisplayName("글 AI 가 준 영어 장면이 있으면 그대로 FLUX 에 — 번역 호출 없음(추가 비용 없음), seed 는 일과로 고정")
  void flux_withEnglishScene() {
    when(fluxImageClient.generate(any(), any(), any())).thenReturn(FLUX_IMAGE);

    GeneratedImage image = generator.generate(request("The character picks up a red umbrella."));

    assertThat(image).isSameAs(FLUX_IMAGE);
    verify(fluxImageClient).generate(
      "The character picks up a red umbrella.", CharacterType.LULU, FluxSeed.of(SEED_KEY));
    verifyNoInteractions(translator);
    verify(openAiClient, never()).generateCardImage(any(), any());
  }

  @Test
  @DisplayName("보호자가 직접 추가한 카드(영어 장면 없음)는 싼 글 모델로 한 줄 번역해 FLUX 에")
  void flux_withoutEnglish_translates() {
    when(translator.translateImagePrompt("우산을 챙겨요")).thenReturn("The character picks up an umbrella.");
    when(fluxImageClient.generate(any(), any(), any())).thenReturn(FLUX_IMAGE);

    assertThat(generator.generate(request(null))).isSameAs(FLUX_IMAGE);
    verify(fluxImageClient).generate(
      eq("The character picks up an umbrella."), eq(CharacterType.LULU), eq(FluxSeed.of(SEED_KEY)));
  }

  @Test
  @DisplayName("영어 장면에 한국어가 섞여 오면 쓰지 않고 번역한다 — schnell 은 한국어를 보면 사람을 그린다")
  void flux_koreanInEnglishField_translates() {
    when(translator.translateImagePrompt("우산을 챙겨요")).thenReturn("The character picks up an umbrella.");
    when(fluxImageClient.generate(any(), any(), any())).thenReturn(FLUX_IMAGE);

    generator.generate(request("The character 우산을 챙겨요"));

    verify(translator).translateImagePrompt("우산을 챙겨요");
  }

  @Test
  @DisplayName("번역이 실패하면 그 카드만 OpenAI 로 — FLUX 는 부르지 않는다")
  void translationFails_fallsBackToOpenAi() {
    when(translator.translateImagePrompt(anyString())).thenThrow(new IllegalStateException("번역 실패"));

    assertThat(generator.generate(request(null))).isSameAs(OPENAI_IMAGE);
    verify(openAiClient).generateCardImage(argThat(scene -> "우산을 챙겨요".equals(scene.stepDescription())), eq(CharacterType.LULU));
    verify(fluxImageClient, never()).generate(any(), any(), any());
  }

  @Test
  @DisplayName("FLUX 가 잔액 소진(402)·에러·타임아웃이면 그 카드만 OpenAI 로")
  void fluxFails_fallsBackToOpenAi() {
    when(fluxImageClient.generate(any(), any(), any())).thenThrow(
      HttpClientErrorException.create(org.springframework.http.HttpStatus.PAYMENT_REQUIRED,
        "Payment Required", null, null, null));

    assertThat(generator.generate(request("The character picks up an umbrella."))).isSameAs(OPENAI_IMAGE);
    verify(openAiClient).generateCardImage(argThat(scene -> "우산을 챙겨요".equals(scene.stepDescription())), eq(CharacterType.LULU));
  }

  @Test
  @DisplayName("FLUX 키가 없으면 부르지 않고 OpenAI 로")
  void fluxUnavailable_fallsBackToOpenAi() {
    when(fluxImageClient.available()).thenReturn(false);

    assertThat(generator.generate(request("The character picks up an umbrella."))).isSameAs(OPENAI_IMAGE);
    verify(fluxImageClient, never()).generate(any(), any(), any());
    verifyNoInteractions(translator);
  }

  @Test
  @DisplayName("OpenAI 도 못 쓰면 FLUX 실패를 그대로 올린다 — 부르는 쪽이 기본 그림으로 덮는다")
  void fluxFails_andNoOpenAi_throws() {
    when(imageClientRouter.of(ImageProvider.OPENAI)).thenReturn(Optional.empty());
    when(fluxImageClient.generate(any(), any(), any())).thenThrow(new IllegalStateException("FLUX 실패"));

    assertThatThrownBy(() -> generator.generate(request("The character picks up an umbrella.")))
      .hasMessageContaining("FLUX 실패");
  }


  // ── 그림 방식 (#457) ────────────────────────────────────────────────

  private CardImageGenerator.CardImageRequest realistic(String imagePromptEn) {
    return new CardImageGenerator.CardImageRequest(
      "우산을 챙겨요", imagePromptEn, CharacterType.LULU, SEED_KEY, ImageStyle.REALISTIC);
  }

  @Test
  @DisplayName("그림 방식을 비워 만든 요청은 만화다 — 기존 호출부가 그대로 만화로 돈다")
  void nullImageStyle_isCartoon() {
    assertThat(new CardImageGenerator.CardImageRequest("설명", null, null, "k", null).imageStyle())
      .isEqualTo(ImageStyle.CARTOON);
  }

  @Test
  @DisplayName("실사 + FLUX 가 아닌 제공자 — 캐릭터 없는 실사 전용 호출을 부르고 만화 호출은 부르지 않는다")
  void realistic_otherProvider_callsRealisticOnly() {
    when(imageClientRouter.selected()).thenReturn(ImageProvider.OPENAI);
    when(imageClientRouter.current()).thenReturn(openAiClient);
    when(openAiClient.generateRealisticImage("우산을 챙겨요")).thenReturn(OPENAI_IMAGE);

    assertThat(generator.generate(realistic("The character picks up an umbrella."))).isSameAs(OPENAI_IMAGE);

    verify(openAiClient, never()).generateCardImage(any(), any());
    verifyNoInteractions(fluxImageClient, translator);
  }

  @Test
  @DisplayName("실사 + FLUX — 글 AI 의 영어 장면(The character 관례)을 버리고 실사용 번역으로 카드마다 새로 만든다")
  void realistic_flux_ignoresImagePromptEnAndTranslatesRealistic() {
    when(translator.translateRealisticImagePrompt("우산을 챙겨요"))
      .thenReturn("A red umbrella leaning on a white wall.");
    when(fluxImageClient.generateRealistic(any(), any())).thenReturn(FLUX_IMAGE);

    assertThat(generator.generate(realistic("The character picks up a red umbrella."))).isSameAs(FLUX_IMAGE);

    verify(fluxImageClient).generateRealistic("A red umbrella leaning on a white wall.", FluxSeed.of(SEED_KEY));
    verify(translator, never()).translateImagePrompt(anyString());
    verify(fluxImageClient, never()).generate(any(), any(), any());
  }

  @Test
  @DisplayName("실사 + FLUX 번역이 실패하면 그 카드만 OpenAI 실사로 — 만화 프롬프트로 새지 않는다")
  void realistic_translationFails_fallsBackToOpenAiRealistic() {
    when(translator.translateRealisticImagePrompt(anyString())).thenThrow(new IllegalStateException("번역 실패"));
    when(openAiClient.generateRealisticImage("우산을 챙겨요")).thenReturn(OPENAI_IMAGE);

    assertThat(generator.generate(realistic(null))).isSameAs(OPENAI_IMAGE);

    verify(openAiClient, never()).generateCardImage(any(), any());
    verify(fluxImageClient, never()).generateRealistic(any(), any());
  }

  @Test
  @DisplayName("실사 + FLUX 가 실패하면 그 카드만 OpenAI 실사로")
  void realistic_fluxFails_fallsBackToOpenAiRealistic() {
    when(translator.translateRealisticImagePrompt(anyString())).thenReturn("A red umbrella on a white wall.");
    when(fluxImageClient.generateRealistic(any(), any())).thenThrow(new IllegalStateException("FLUX 실패"));
    when(openAiClient.generateRealisticImage("우산을 챙겨요")).thenReturn(OPENAI_IMAGE);

    assertThat(generator.generate(realistic(null))).isSameAs(OPENAI_IMAGE);
    verify(openAiClient, never()).generateCardImage(any(), any());
  }

  @Test
  @DisplayName("실사 + FLUX 키 없음 — FLUX 도 번역도 부르지 않고 OpenAI 실사로")
  void realistic_fluxUnavailable_fallsBackToOpenAiRealistic() {
    when(fluxImageClient.available()).thenReturn(false);
    when(openAiClient.generateRealisticImage("우산을 챙겨요")).thenReturn(OPENAI_IMAGE);

    assertThat(generator.generate(realistic(null))).isSameAs(OPENAI_IMAGE);
    verifyNoInteractions(translator);
  }

  @Test
  @DisplayName("직접 사진이 여기까지 오면 아무 제공자도 부르지 않고 막는다 — 돈이 나가기 전에")
  void photoOnly_neverCallsAnyProvider() {
    CardImageGenerator.CardImageRequest photoOnly = new CardImageGenerator.CardImageRequest(
      "우산을 챙겨요", null, CharacterType.LULU, SEED_KEY, ImageStyle.PHOTO_ONLY);

    assertThatThrownBy(() -> generator.generate(photoOnly)).isInstanceOf(IllegalStateException.class);
    verifyNoInteractions(fluxImageClient, translator, openAiClient);
  }
}
