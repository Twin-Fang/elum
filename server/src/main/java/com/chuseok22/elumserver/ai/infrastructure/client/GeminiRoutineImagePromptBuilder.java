package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.core.CardScene;
import com.chuseok22.elumserver.ai.core.ImagePromptLanguage;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.chuseok22.elumserver.common.infrastructure.json.DefaultJsonMapper;
import org.springframework.stereotype.Component;

// 실제 이미지 생성 호출(GeminiImageClient)과 관리자 미리보기(AdminPromptService)가 항상
// 같은 프롬프트 문자열을 만들도록 조립 로직을 이 컴포넌트 하나로 모은다. 이미지 호출은
// System Instruction을 쓰지 않으므로(GeminiGenerateContentRequest의 systemInstruction이
// null), 프리픽스와 장면 정보를 텍스트 파트 하나에 함께 담는다.
@Component
public class GeminiRoutineImagePromptBuilder {

  // 공통 JSON 매퍼 (DefaultJsonMapper)
  private final ObjectMapper objectMapper = DefaultJsonMapper.SHARED;

  /**
   * @param referenceImageProvided 참조 이미지를 함께 보내는가. <b>사실대로 적는다</b> —
   *                               보내지 않으면서 보낸다고 하면 모델이 그림을 믿고
   *                               생김새를 덜 신경 쓴다
   */
  public String build(
    String prefix, String stepDescription, CharacterType characterType,
    boolean referenceImageProvided
  ) {
    return build(prefix, stepDescription, characterType, referenceImageProvided, ImagePromptLanguage.KO);
  }

  /**
   * @param language 지시문 언어. EN 이면 장면 머리말과 생김새도 영어로 싣는다 — 지시문만 영어이고
   *                 생김새가 한국어면 줄인 토큰이 다시 는다. 카드 설명은 언어와 무관하게
   *                 그대로 싣는다(보호자가 쓴 한국어, 짧다).
   */
  public String build(
    String prefix, String stepDescription, CharacterType characterType,
    boolean referenceImageProvided, ImagePromptLanguage language
  ) {
    return build(prefix, CardScene.descriptionOnly(stepDescription), characterType, referenceImageProvided, language);
  }

  /**
   * 제목·영어 장면까지 담는 조립: 지시문 + 빈 줄 + 장면 머리말 + 장면 JSON (없는 필드는 생략)
   */
  public String build(
    String prefix, CardScene scene, CharacterType characterType,
    boolean referenceImageProvided, ImagePromptLanguage language
  ) {
    GeminiImageAiInput input = new GeminiImageAiInput(
      "CREATE_ROUTINE_CARD_IMAGE",
      new GeminiImageAiInput.Scene(
        scene.routineTitle(), scene.stepTitle(), scene.stepDescription(), scene.sceneDetail()),
      characterType == null
        ? null
        : new GeminiImageAiInput.Character(
          characterType,
          language == ImagePromptLanguage.EN ? characterType.getAppearanceEn() : characterType.getAppearance(),
          referenceImageProvided
        )
    );
    return prefix + "\n\n" + language.getSceneLabel() + ":\n" + toJson(input);
  }

  private String toJson(GeminiImageAiInput input) {
    try {
      return objectMapper.writeValueAsString(input);
    } catch (JsonProcessingException e) {
      throw new IllegalStateException("Gemini 이미지 요청 JSON 직렬화 실패", e);
    }
  }
}
