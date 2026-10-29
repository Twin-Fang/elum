package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.core.CardScene;
import com.chuseok22.elumserver.ai.core.ImageCardLayoutRules;
import com.chuseok22.elumserver.ai.core.ImagePromptLanguage;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * OpenAI·Gemini 그림 프롬프트를 만든다 — 어느 언어 지시문을 쓸지 여기서 한 번만 정한다.
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
    return compose(CardScene.descriptionOnly(stepDescription), characterType, referenceImageProvided);
  }

  /**
   * 만화 카드 그림 프롬프트: DB 지시문 + 화면 규격(코드) + 장면 정보
   * 캐릭터가 없으면 규격을 붙이지 않음 (캐릭터 전제 규칙)
   */
  public String compose(CardScene scene, CharacterType characterType, boolean referenceImageProvided) {
    ImagePromptLanguage language = language();
    String prefix = promptTemplateService.getContent(language.getPrefixKey());
    if (characterType != null) {
      prefix = prefix + "\n\n" + ImageCardLayoutRules.of(language);
    }
    return imagePromptBuilder.build(prefix, scene, characterType, referenceImageProvided, language);
  }

  /**
   * 실사 방식의 그림 프롬프트. 언어 설정(KO/EN)을 무시하고 영어 단일 키를 쓴다 — 실사 지시문은 한국어판이
   * 없다. 캐릭터가 없어 생김새·참조 이미지 블록도 없다(빌더가 null 캐릭터를 생략한다).
   */
  public String composeRealistic(String stepDescription) {
    String prefix = promptTemplateService.getContent(PromptKey.REALISTIC_ROUTINE_IMAGE_PREFIX);
    return imagePromptBuilder.build(prefix, stepDescription, null, false, ImagePromptLanguage.EN);
  }
}
