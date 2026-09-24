package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.core.ImagePromptLanguage;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * OpenAI·Gemini 그림 프롬프트를 만든다 — 어느 언어 지시문을 쓸지 여기서 한 번만 정한다 (#375).
 *
 * <p>두 제공자가 각자 설정을 읽으면 한쪽만 영어로 바뀌는 일이 생긴다.
 */
@Component
@RequiredArgsConstructor
public class RoutineImagePromptComposer {

  private final PromptTemplateService promptTemplateService;
  private final SystemConfigService systemConfigService;
  private final GeminiRoutineImagePromptBuilder imagePromptBuilder;

  public ImagePromptLanguage language() {
    return ImagePromptLanguage.from(systemConfigService.getString(ConfigKey.IMAGE_PROMPT_LANGUAGE));
  }

  public String compose(String stepDescription, CharacterType characterType, boolean referenceImageProvided) {
    ImagePromptLanguage language = language();
    String prefix = promptTemplateService.getContent(language.getPrefixKey());
    return imagePromptBuilder.build(prefix, stepDescription, characterType, referenceImageProvided, language);
  }
}
