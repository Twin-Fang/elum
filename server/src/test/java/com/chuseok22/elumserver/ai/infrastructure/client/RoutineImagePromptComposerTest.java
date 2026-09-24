package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.core.ImagePromptLanguage;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * OpenAI·Gemini 그림 지시문의 언어 고르기 (#375).
 *
 * <p>운영 DB 의 프롬프트는 배포로 바뀌지 않는다. 그래서 언어는 관리자 설정 하나로 고르고,
 * 기본값은 지금과 같은 한국어다 — 배포만으로 그림이 달라지지 않는다.
 */
class RoutineImagePromptComposerTest {

  private SystemConfigService systemConfigService;
  private RoutineImagePromptComposer composer;

  @BeforeEach
  void setUp() {
    systemConfigService = mock(SystemConfigService.class);
    PromptTemplateService promptTemplateService = mock(PromptTemplateService.class);
    when(promptTemplateService.getContent(PromptKey.GEMINI_ROUTINE_IMAGE_PREFIX)).thenReturn("한국어 지시문");
    when(promptTemplateService.getContent(PromptKey.ROUTINE_IMAGE_PREFIX_EN)).thenReturn("English rules");
    composer = new RoutineImagePromptComposer(
      promptTemplateService, systemConfigService, new GeminiRoutineImagePromptBuilder());
  }

  private void language(String value) {
    when(systemConfigService.getString(ConfigKey.IMAGE_PROMPT_LANGUAGE)).thenReturn(value);
  }

  @Test
  @DisplayName("KO 면 지금과 똑같은 한국어 지시문을 쓴다")
  void korean_keepsCurrentPrompt() {
    language("KO");

    String prompt = composer.compose("옷을 입어요.", CharacterType.LULU, false);

    assertThat(prompt).startsWith("한국어 지시문\n\n장면 정보:\n");
    assertThat(prompt).contains(CharacterType.LULU.getAppearance());
  }

  @Test
  @DisplayName("EN 이면 영어 지시문 키와 영어 생김새를 쓴다")
  void english_usesEnglishKeyAndAppearance() {
    language("EN");

    String prompt = composer.compose("옷을 입어요.", CharacterType.LULU, true);

    assertThat(prompt).startsWith("English rules\n\nScene info:\n");
    assertThat(prompt).contains(CharacterType.LULU.getAppearanceEn());
    assertThat(prompt).contains("\"referenceImageProvided\":true");
  }

  @Test
  @DisplayName("값이 망가져 있으면 한국어로 — 설정 하나로 그림이 멈추지 않게")
  void corrupted_fallsBackToKorean() {
    language("JP");

    assertThat(composer.language()).isEqualTo(ImagePromptLanguage.KO);
    assertThat(composer.compose("옷을 입어요.", null, false)).startsWith("한국어 지시문");
  }
}
