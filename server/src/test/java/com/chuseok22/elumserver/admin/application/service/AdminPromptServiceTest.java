package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.application.service.SensitiveInfoGuardService;
import com.chuseok22.elumserver.ai.core.ImagePromptLanguage;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiImageClient;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiRoutineImagePromptBuilder;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageGenerationClient;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiTextClient;
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
  private SensitiveInfoGuardService sensitiveInfoGuardService;

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
  @DisplayName("LOCAL_LLM_SENSITIVE_INFO_CHECK preview는 <text> 태그가 아니라 SensitiveInfoGuardService의 JSON 래핑을 사용한다")
  void preview_localLlmPrefix_usesJsonWrappingNotTextTag() {
    when(sensitiveInfoGuardService.buildUserContent("김민준입니다")).thenReturn("{\"text\":\"김민준입니다\"}");

    String result = adminPromptService.preview(
      PromptKey.LOCAL_LLM_SENSITIVE_INFO_CHECK, "시스템 프롬프트", "김민준입니다", null
    );

    assertThat(result).contains("{\"text\":\"김민준입니다\"}");
    assertThat(result).doesNotContain("<text>");
  }
}
