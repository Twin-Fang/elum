package com.chuseok22.elumserver.ai.application.service;

import static org.assertj.core.api.Assertions.assertThat;
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

/**
 * 일본어·중국어 일과의 FLUX 영어 한 줄. FLUX schnell 은 영어가 아닌 글자를 보면 사람을 그린다.
 * 실제 AI 는 부르지 않는다.
 */
@ExtendWith(MockitoExtension.class)
class CardImageGeneratorLocaleTest {

  private static final GeneratedImage FLUX_IMAGE = new GeneratedImage(new byte[]{1}, "jpg");
  private static final GeneratedImage OPENAI_IMAGE = new GeneratedImage(new byte[]{2}, "png");
  private static final String SEED_KEY = FluxSeed.routineKey("profile-1", "雨の日に学校へ行きます");

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
    lenient().when(fluxImageClient.generate(any(), any(), any())).thenReturn(FLUX_IMAGE);
  }

  private CardImageGenerator.CardImageRequest request(String description, String imagePromptEn) {
    return new CardImageGenerator.CardImageRequest(
      description, imagePromptEn, CharacterType.LULU, SEED_KEY, ImageStyle.CARTOON);
  }

  @Test
  @DisplayName("영어 장면에 일본어가 섞여 오면 쓰지 않고 번역한다")
  void japaneseInEnglishField_isTranslated() {
    when(translator.translateImagePrompt("傘を持ちます")).thenReturn("The character holds a red umbrella.");

    generator.generate(request("傘を持ちます", "The character 傘を持ちます"));

    verify(translator).translateImagePrompt("傘を持ちます");
    verify(fluxImageClient).generate(
      eq("The character holds a red umbrella."), eq(CharacterType.LULU), eq(FluxSeed.of(SEED_KEY)));
  }

  @Test
  @DisplayName("영어 장면에 중국어가 섞여 오면 쓰지 않고 번역한다")
  void chineseInEnglishField_isTranslated() {
    when(translator.translateImagePrompt("带上雨伞")).thenReturn("The character packs a small umbrella.");

    generator.generate(request("带上雨伞", "The character 带上雨伞"));

    verify(translator).translateImagePrompt("带上雨伞");
  }

  @Test
  @DisplayName("번역 결과가 영어가 아니면(중국어 그대로) FLUX 에 넣지 않고 그 카드만 OpenAI 로 돌린다")
  void nonEnglishTranslation_fallsBackToOpenAi() {
    when(translator.translateImagePrompt("带上雨伞")).thenReturn("The character 带上雨伞");

    GeneratedImage image = generator.generate(request("带上雨伞", null));

    assertThat(image).isSameAs(OPENAI_IMAGE);
    verify(openAiClient).generateCardImage(argThat(scene -> "带上雨伞".equals(scene.stepDescription())), eq(CharacterType.LULU));
    verify(fluxImageClient, never()).generate(any(), any(), any());
  }

  @Test
  @DisplayName("악센트가 든 라틴 글자는 거르지 않는다 — 영어 장면에 café·señal 이 나와도 FLUX 로 간다")
  void accentedLatinIsAccepted() {
    generator.generate(request("Saca el paraguas", "The character holds a café umbrella near the señal."));

    verifyNoInteractions(translator);
    verify(fluxImageClient).generate(
      eq("The character holds a café umbrella near the señal."), eq(CharacterType.LULU), eq(FluxSeed.of(SEED_KEY)));
  }
}
