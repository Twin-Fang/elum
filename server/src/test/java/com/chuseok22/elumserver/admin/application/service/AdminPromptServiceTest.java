package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import com.chuseok22.elumserver.admin.application.dto.response.PromptTestResponse;
import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.ai.infrastructure.client.FluxPromptBuilder;
import com.chuseok22.elumserver.ai.infrastructure.client.CloudflareImageClient;
import com.chuseok22.elumserver.ai.infrastructure.client.FluxImageClient;
import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.core.ImagePromptLanguage;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiImageClient;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiRoutineImagePromptBuilder;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageGenerationClient;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiTextClient;
import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class AdminPromptServiceTest {

  @Mock
  private PromptTemplateService promptTemplateService;

  @Mock
  private GeminiTextClient geminiTextClient;

  @Mock
  private GeminiImageClient geminiImageClient;

  @Mock
  private GeminiRoutineImagePromptBuilder imagePromptBuilder;

  @Mock
  private ImageClientRouter imageClientRouter;

  @Mock
  private ImageGenerationClient imageGenerationClient;

  @Mock
  private FluxImageClient fluxImageClient;

  @Mock
  private CloudflareImageClient cloudflareImageClient;

  @Mock
  private FluxPromptBuilder fluxPromptBuilder;

  @Mock
  private TextClientRouter textClientRouter;

  @InjectMocks
  private AdminPromptService adminPromptService;

  @Test
  @DisplayName("GEMINI_ROUTINE_CREATE_PREFIX preview는 GeminiTextClient의 실제 조립 메서드를 그대로 사용한다")
  void preview_createPrefix_delegatesToGeminiTextClientBuilder() {
    when(geminiTextClient.buildCreateRoutineUserContent("일과 원문", null, java.util.Set.of(), java.util.List.of()))
      .thenReturn("{\"task\":\"CREATE_ROUTINE\"}");

    String result = adminPromptService.preview(
      PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, "시스템 프롬프트", "일과 원문", null
    );

    assertThat(result).contains("[System]\n시스템 프롬프트");
    assertThat(result).contains("{\"task\":\"CREATE_ROUTINE\"}");
    assertThat(result).doesNotContain("<text>");
  }

  @Test
  @DisplayName("GEMINI_ROUTINE_IMAGE_PREFIX preview는 GeminiRoutineImagePromptBuilder를 그대로 사용한다")
  void preview_imagePrefix_delegatesToImagePromptBuilder() {
    // preview도 지금 고른 제공자 기준으로 만든다 (#269) — 참조 이미지를 보내는지에 따라
    // 프롬프트가 달라지므로, 미리보기가 실제와 같으려면 같은 판단을 거쳐야 한다.
    when(imageClientRouter.current()).thenReturn(imageGenerationClient);
    when(imageGenerationClient.supportsCharacterReference()).thenReturn(true);
    when(imagePromptBuilder.build("이미지 프롬프트", "옷을 입어요", CharacterType.LULU, true, ImagePromptLanguage.KO))
      .thenReturn("이미지 프롬프트\n\n장면 정보:\n{...}");

    String result = adminPromptService.preview(
      PromptKey.GEMINI_ROUTINE_IMAGE_PREFIX, "이미지 프롬프트", "옷을 입어요", CharacterType.LULU
    );

    assertThat(result).isEqualTo("이미지 프롬프트\n\n장면 정보:\n{...}");
  }

  @Test
  @DisplayName("영어 그림 지시문 preview 는 영어로 조립한다 — 한국어 머리말·생김새가 섞이면 미리보기를 믿을 수 없다 (#375)")
  void preview_englishImagePrefix_buildsInEnglish() {
    when(imageClientRouter.current()).thenReturn(imageGenerationClient);
    when(imageGenerationClient.supportsCharacterReference()).thenReturn(false);
    when(imagePromptBuilder.build("English rules", "옷을 입어요", CharacterType.LULU, false, ImagePromptLanguage.EN))
      .thenReturn("English rules\n\nScene info:\n{...}");

    String result = adminPromptService.preview(
      PromptKey.ROUTINE_IMAGE_PREFIX_EN, "English rules", "옷을 입어요", CharacterType.LULU
    );

    assertThat(result).isEqualTo("English rules\n\nScene info:\n{...}");
  }

  @Test
  @DisplayName("FLUX 지시문 preview 는 FLUX 조립기 그대로 — 샘플 입력은 영어 장면 한 줄이다 (#373)")
  void preview_fluxPrefix_usesFluxBuilder() {
    when(fluxPromptBuilder.build("Style.", "The character waves.", CharacterType.LULU))
      .thenReturn("Style. Only one character: ... The kitten waves.");

    String result = adminPromptService.preview(
      PromptKey.FLUX_ROUTINE_IMAGE_PREFIX, "Style.", "The character waves.", CharacterType.LULU);

    assertThat(result).isEqualTo("Style. Only one character: ... The kitten waves.");
  }

  @Test
  @DisplayName("FLUX 지시문 시험은 지금 고른 제공자와 무관하게 FLUX 로 그린다 — 운영은 OPENAI 인 채로 시험한다 (#373)")
  void test_fluxPrefix_callsFluxEvenIfNotSelected() {
    when(fluxImageClient.generateForTest("Style.", "The character waves.", CharacterType.LULU))
      .thenReturn(new GeneratedImage(new byte[]{1, 2}, "jpg"));

    PromptTestResponse response = adminPromptService.test(
      PromptKey.FLUX_ROUTINE_IMAGE_PREFIX, "Style.", "The character waves.", CharacterType.LULU);

    assertThat(response.imageDataUri()).startsWith("data:image/jpg;base64,");
    verify(imageClientRouter, never()).current();
  }

  @Test
  @DisplayName("CLOUDFLARE 를 고른 때 FLUX 지시문 미리보기·시험은 Cloudflare 모양(카드 그림 인물)으로 — 운영과 다른 그림을 보고 고치지 않게")
  void fluxPrefix_cloudflareSelected_usesCloudflare() {
    when(imageClientRouter.selected()).thenReturn(com.chuseok22.elumserver.ai.core.ImageProvider.CLOUDFLARE);
    when(imageClientRouter.englishScene(com.chuseok22.elumserver.ai.core.ImageProvider.CLOUDFLARE))
      .thenReturn(java.util.Optional.of(cloudflareImageClient));
    when(cloudflareImageClient.buildCartoonPrompt("Style.", "The character waves.", CharacterType.LULU))
      .thenReturn("Style. Only one character: a child. The child waves.");
    when(cloudflareImageClient.generateForTest("Style.", "The character waves.", CharacterType.LULU))
      .thenReturn(new GeneratedImage(new byte[]{1}, "jpg"));

    assertThat(adminPromptService.preview(
      PromptKey.FLUX_ROUTINE_IMAGE_PREFIX, "Style.", "The character waves.", CharacterType.LULU))
      .isEqualTo("Style. Only one character: a child. The child waves.");
    adminPromptService.test(PromptKey.FLUX_ROUTINE_IMAGE_PREFIX, "Style.", "The character waves.", CharacterType.LULU);

    verify(cloudflareImageClient).generateForTest("Style.", "The character waves.", CharacterType.LULU);
    verify(fluxImageClient, never()).generateForTest(any(), any(), any());
  }

  @Test
  @DisplayName("인물 생김새 시험은 저장된 화풍 + 저장 전 생김새로 Cloudflare 가 그린다")
  void subjectAppearance_testsWithCloudflare() {
    when(cloudflareImageClient.available()).thenReturn(true);
    when(promptTemplateService.getContent(PromptKey.FLUX_ROUTINE_IMAGE_PREFIX)).thenReturn("Style.");
    when(cloudflareImageClient.generateWithAppearanceForTest("Style.", "a kid in a red hoodie", "The character waves."))
      .thenReturn(new GeneratedImage(new byte[]{1}, "jpg"));

    PromptTestResponse response = adminPromptService.test(
      PromptKey.CARD_IMAGE_SUBJECT_CHILD, "a kid in a red hoodie", "The character waves.", null);

    assertThat(response.imageDataUri()).startsWith("data:image/jpg;base64,");
  }

  @Test
  @DisplayName("Cloudflare 키가 없으면 인물 생김새 시험은 부르지 않고 IMAGE_PROVIDER_UNAVAILABLE — 빈 주소로 요청을 보내지 않는다")
  void subjectAppearance_unavailable_keepsErrorCode() {
    when(cloudflareImageClient.available()).thenReturn(false);

    assertThatThrownBy(() -> adminPromptService.test(PromptKey.CARD_IMAGE_SUBJECT_CHILD, "a kid", "The character waves.", null))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.IMAGE_PROVIDER_UNAVAILABLE));
    verify(cloudflareImageClient, never()).generateWithAppearanceForTest(any(), any(), any());
  }

  @Test
  @DisplayName("번역 지시문 시험은 한 줄 결과를 보여준다 (#373)")
  void test_translatePrompt_showsLine() {
    when(geminiTextClient.translateImagePromptForTest("Rewrite.", "우산을 챙겨요"))
      .thenReturn("The character picks up an umbrella.");

    PromptTestResponse response = adminPromptService.test(
      PromptKey.FLUX_IMAGE_PROMPT_TRANSLATE, "Rewrite.", "우산을 챙겨요", null);

    assertThat(response.result()).isEqualTo(java.util.Map.of("imagePromptEn", "The character picks up an umbrella."));
  }


  @Test
  @DisplayName("실사 그림 지시문 preview 는 선택한 캐릭터를 무시하고 캐릭터 없이 영어로 조립한다 (#457)")
  void preview_realisticPrefix_ignoresCharacter() {
    when(imagePromptBuilder.build("Realistic rules", "우산", null, false, ImagePromptLanguage.EN))
      .thenReturn("Realistic rules\n\nScene info:\n{...}");

    String result = adminPromptService.preview(
      PromptKey.REALISTIC_ROUTINE_IMAGE_PREFIX, "Realistic rules", "우산", CharacterType.LULU);

    assertThat(result).isEqualTo("Realistic rules\n\nScene info:\n{...}");
  }

  @Test
  @DisplayName("실사 번역 지시문 preview 는 [System]/[User] 로 조립한다 (#457)")
  void preview_realisticTranslate_buildsSystemAndUser() {
    when(geminiTextClient.buildTranslateUserContent("우산을 챙겨요")).thenReturn("{\"task\":\"TRANSLATE_CARD_SCENE\"}");

    String result = adminPromptService.preview(
      PromptKey.REALISTIC_IMAGE_PROMPT_TRANSLATE, "Rewrite.", "우산을 챙겨요", null);

    assertThat(result).contains("[System]\nRewrite.").contains("TRANSLATE_CARD_SCENE");
  }

  @Test
  @DisplayName("실사 그림 지시문 시험은 캐릭터 없이(null) 영어 지시문으로 그린다 (#457)")
  void test_realisticPrefix_drawsWithoutCharacter() {
    when(imageClientRouter.current()).thenReturn(imageGenerationClient);
    when(imageGenerationClient.generateImageForTest("Realistic rules", ImagePromptLanguage.EN, "우산", null))
      .thenReturn(new GeneratedImage(new byte[]{1, 2}, "png"));

    PromptTestResponse response = adminPromptService.test(
      PromptKey.REALISTIC_ROUTINE_IMAGE_PREFIX, "Realistic rules", "우산", CharacterType.POPO);

    assertThat(response.imageDataUri()).startsWith("data:image/png;base64,");
  }

  @Test
  @DisplayName("실사 번역 지시문 시험은 한 줄 결과를 보여준다 (#457)")
  void test_realisticTranslate_showsLine() {
    when(geminiTextClient.translateImagePromptForTest("Rewrite.", "우산을 챙겨요"))
      .thenReturn("A red umbrella leaning on a white wall.");

    PromptTestResponse response = adminPromptService.test(
      PromptKey.REALISTIC_IMAGE_PROMPT_TRANSLATE, "Rewrite.", "우산을 챙겨요", null);

    assertThat(response.result()).isEqualTo(java.util.Map.of("imagePromptEn", "A red umbrella leaning on a white wall."));
  }

  @Test
  @DisplayName("모든 프롬프트 키가 preview 를 예외 없이 처리한다 — 새 키가 switch 에서 빠지면 관리자 화면이 죽는다")
  void preview_everyKey_noException() {
    for (PromptKey key : PromptKey.values()) {
      org.assertj.core.api.Assertions.assertThatCode(
        () -> adminPromptService.preview(key, "content", "sample", null)).as(key.name()).doesNotThrowAnyException();
    }
  }

  @Test
  @DisplayName("텍스트 제공자를 쓸 수 없으면 TEXT_PROVIDER_UNAVAILABLE 코드가 그대로 나간다")
  void test_textProviderUnavailable_keepsErrorCode() {
    when(textClientRouter.current()).thenThrow(new CustomException(ErrorCode.TEXT_PROVIDER_UNAVAILABLE));

    assertThatThrownBy(() -> adminPromptService.test(
      PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, "Rules.", "우산", null))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TEXT_PROVIDER_UNAVAILABLE));
  }

  @Test
  @DisplayName("이미지 제공자를 쓸 수 없으면 IMAGE_PROVIDER_UNAVAILABLE 코드가 그대로 나간다")
  void test_imageProviderUnavailable_keepsErrorCode() {
    when(imageClientRouter.current()).thenThrow(new CustomException(ErrorCode.IMAGE_PROVIDER_UNAVAILABLE));

    assertThatThrownBy(() -> adminPromptService.test(
      PromptKey.REALISTIC_ROUTINE_IMAGE_PREFIX, "Rules.", "우산", null))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.IMAGE_PROVIDER_UNAVAILABLE));
  }

  @Test
  @DisplayName("그 밖의 예외는 PROMPT_TEST_*_FAILED 로 바뀐다")
  void test_unexpectedException_becomesPromptTestFailed() {
    when(geminiTextClient.translateImagePromptForTest("Rewrite.", "우산"))
      .thenThrow(new IllegalStateException("boom"));

    assertThatThrownBy(() -> adminPromptService.test(
      PromptKey.FLUX_IMAGE_PROMPT_TRANSLATE, "Rewrite.", "우산", null))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.PROMPT_TEST_GEMINI_TEXT_FAILED));
  }
}
