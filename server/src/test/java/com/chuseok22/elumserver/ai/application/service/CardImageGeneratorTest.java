package com.chuseok22.elumserver.ai.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.core.FluxSeed;
import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.ai.core.ImageProvider;
import com.chuseok22.elumserver.ai.infrastructure.client.CloudflareImageClient;
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
  @Mock private CloudflareImageClient cloudflareImageClient;
  @Mock private ImageGenerationClient openAiClient;
  @Mock private GeminiTextClient translator;

  private CardImageGenerator generator;

  @BeforeEach
  void setUp() {
    generator = new CardImageGenerator(imageClientRouter, translator);
    lenient().when(imageClientRouter.englishScene(ImageProvider.FLUX)).thenReturn(Optional.of(fluxImageClient));
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

  /// Cloudflare 를 고른 상태 (프로필 캐릭터를 그리지 않는 영어 장면 제공자)
  private void selectCloudflare() {
    when(imageClientRouter.selected()).thenReturn(ImageProvider.CLOUDFLARE);
    when(imageClientRouter.englishScene(ImageProvider.CLOUDFLARE)).thenReturn(Optional.of(cloudflareImageClient));
    lenient().when(cloudflareImageClient.available()).thenReturn(true);
    lenient().when(cloudflareImageClient.shouldDropProfileCharacter()).thenReturn(true);
  }

  @Test
  @DisplayName("CLOUDFLARE 도 영어 장면 경로 — 글 AI 장면을 그대로, 번역 없이, 일과 seed 로")
  void cloudflare_usesEnglishScene() {
    selectCloudflare();
    when(cloudflareImageClient.generate(any(), any(), any())).thenReturn(FLUX_IMAGE);

    assertThat(generator.generate(request("The character picks up a red umbrella."))).isSameAs(FLUX_IMAGE);

    verify(cloudflareImageClient).generate("The character picks up a red umbrella.", CharacterType.LULU, FluxSeed.of(SEED_KEY));
    verifyNoInteractions(translator, fluxImageClient);
  }

  @Test
  @DisplayName("CLOUDFLARE 실패(한도 소진·NSFW 등)면 그 카드만 OpenAI 로, 캐릭터 없이 — 카드 그림에서 캐릭터를 뺀 결정을 지킨다")
  void cloudflareFails_fallsBackToOpenAiWithoutCharacter() {
    selectCloudflare();
    when(cloudflareImageClient.generate(any(), any(), any()))
      .thenThrow(new IllegalStateException("cloudflare daily free allocation used up"));

    assertThat(generator.generate(request("The character picks up an umbrella."))).isSameAs(OPENAI_IMAGE);
    verify(openAiClient).generateCardImage(argThat(scene -> "우산을 챙겨요".equals(scene.stepDescription())), isNull());
  }

  @Test
  @DisplayName("CLOUDFLARE 키가 없으면 부르지 않고 OpenAI 로, 캐릭터 없이")
  void cloudflareUnavailable_fallsBackToOpenAiWithoutCharacter() {
    selectCloudflare();
    when(cloudflareImageClient.available()).thenReturn(false);

    assertThat(generator.generate(request("The character picks up an umbrella."))).isSameAs(OPENAI_IMAGE);
    verify(cloudflareImageClient, never()).generate(any(), any(), any());
    verify(openAiClient).generateCardImage(any(), isNull());
  }

  @Test
  @DisplayName("CLOUDFLARE 하루 한도 소진 날은 번역(유료 글 호출)도 하지 않고 바로 OpenAI 로, 캐릭터 없이")
  void cloudflareSkippedToday_noTranslation_fallsBackToOpenAi() {
    selectCloudflare();
    when(cloudflareImageClient.isTemporarilySkipped()).thenReturn(true);

    // 영어 장면이 없는 카드 (보호자가 직접 추가) — 평소라면 번역부터 한다
    assertThat(generator.generate(request(null))).isSameAs(OPENAI_IMAGE);

    verifyNoInteractions(translator);
    verify(cloudflareImageClient, never()).generate(any(), any(), any());
    verify(openAiClient).generateCardImage(any(), isNull());
  }

  @Test
  @DisplayName("실사 + CLOUDFLARE — 실사 번역 문장으로 그린다")
  void cloudflareRealistic_usesTranslatedScene() {
    selectCloudflare();
    when(translator.translateRealisticImagePrompt("우산을 챙겨요")).thenReturn("A red umbrella on a plain light gray surface.");
    when(cloudflareImageClient.generateRealistic(any(), any())).thenReturn(FLUX_IMAGE);

    assertThat(generator.generate(realistic("The character picks up a red umbrella."))).isSameAs(FLUX_IMAGE);
    verify(cloudflareImageClient).generateRealistic("A red umbrella on a plain light gray surface.", FluxSeed.of(SEED_KEY));
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

  // 다시 그리기 (#1384): 보호자 요청 + 요청 반영 영어 장면
  private static final String GUARDIAN_REQUEST = "Guardian note: 남색 교복을 입혀 줘";
  private static final String REDRAW_SCENE = "The character, wearing a navy school uniform, picks up a red umbrella.";

  private CardImageGenerator.CardImageRequest redrawRequest() {
    return new CardImageGenerator.CardImageRequest("우산을 챙겨요", "The character picks up a red umbrella.",
      CharacterType.LULU, SEED_KEY, ImageStyle.CARTOON, "비 오는 날 학교에 가요", "우산 챙기기", GUARDIAN_REQUEST);
  }

  @Test
  @DisplayName("다시 그리기는 Cloudflare 의 요청 반영 경로로 — 옷·머리 요청이 기본 생김새에 지지 않게 (#1384)")
  void cloudflareRedraw_usesGuardianRequestPath() {
    selectCloudflare();
    when(translator.translateImagePrompt("우산을 챙겨요 (" + GUARDIAN_REQUEST + ")")).thenReturn(REDRAW_SCENE);
    when(cloudflareImageClient.generateWithGuardianRequest(any(), any(), any())).thenReturn(FLUX_IMAGE);

    assertThat(generator.generate(redrawRequest())).isSameAs(FLUX_IMAGE);

    verify(cloudflareImageClient).generateWithGuardianRequest(REDRAW_SCENE, CharacterType.LULU, FluxSeed.of(SEED_KEY));
    verify(cloudflareImageClient, never()).generate(any(), any(), any());
  }

  @Test
  @DisplayName("다시 그리기에서 Cloudflare 가 실패하면 OpenAI 도 같은 요청 반영 장면으로 — 예비 그림이 요청을 무시하지 않게 (#1384)")
  void cloudflareRedrawFails_openAiUsesSameRedrawScene() {
    selectCloudflare();
    when(translator.translateImagePrompt(anyString())).thenReturn(REDRAW_SCENE);
    when(cloudflareImageClient.generateWithGuardianRequest(any(), any(), any()))
      .thenThrow(new IllegalStateException("cloudflare image failed"));

    assertThat(generator.generate(redrawRequest())).isSameAs(OPENAI_IMAGE);

    verify(openAiClient).generateCardImage(argThat(scene -> REDRAW_SCENE.equals(scene.stepDescription())
      && GUARDIAN_REQUEST.equals(scene.guardianRequest()) && scene.stepTitle() == null && scene.sceneDetail() == null),
      isNull());
  }

  @Test
  @DisplayName("Cloudflare 한도 소진 날의 다시 그리기도 요청을 번역해 OpenAI 에 같은 장면으로 (#1384)")
  void cloudflareSkippedRedraw_translatesForOpenAi() {
    selectCloudflare();
    when(cloudflareImageClient.isTemporarilySkipped()).thenReturn(true);
    when(translator.translateImagePrompt(anyString())).thenReturn(REDRAW_SCENE);

    assertThat(generator.generate(redrawRequest())).isSameAs(OPENAI_IMAGE);

    verify(openAiClient).generateCardImage(argThat(scene -> REDRAW_SCENE.equals(scene.stepDescription())), isNull());
    verify(cloudflareImageClient, never()).generateWithGuardianRequest(any(), any(), any());
  }

  @Test
  @DisplayName("다시 그리기 장면 번역이 실패하면 OpenAI 는 지금처럼 원래 설명 + 요청으로 — 다시 그리기가 멈추지 않게 (#1384)")
  void cloudflareSkippedRedraw_translationFails_usesOriginalDescription() {
    selectCloudflare();
    when(cloudflareImageClient.isTemporarilySkipped()).thenReturn(true);
    when(translator.translateImagePrompt(anyString())).thenThrow(new IllegalStateException("번역 실패"));

    assertThat(generator.generate(redrawRequest())).isSameAs(OPENAI_IMAGE);

    verify(openAiClient).generateCardImage(argThat(scene -> "우산을 챙겨요".equals(scene.stepDescription())
      && GUARDIAN_REQUEST.equals(scene.guardianRequest())), isNull());
  }
}
