package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.ai.core.ContentLanguageSpec;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Gemini 구조화 응답 스키마: 일과 생성, 추가 질문, 카드 영어 장면 번역
 * 스키마는 코드에 둠 (지시문은 운영 DB, 스키마는 배포로 바로 바뀜)
 */
final class GeminiRoutineSchemas {

  private GeminiRoutineSchemas() {
  }

  static final Map<String, Object> IMAGE_PROMPT_SCHEMA = Map.of(
    "type", "object",
    "properties", Map.of("imagePromptEn", Map.of("type", "string")),
    "required", List.of("imagePromptEn")
  );

  /// 카드 설명(description) 스키마 설명. 지시문(운영 DB)과 별개로 스키마는 코드라 배포로 바로 바뀐다.
  /// 길이 기준이 예시에 끌려가므로 예시도 짧게 둔다. ko 사양의 문장이고 다른 언어는 ContentLanguageSpec 이 준다.
  static final String STEP_DESCRIPTION_HINT = ContentLanguageSpec.KO_STEP_DESCRIPTION_HINT;

  /// 카드마다 받는 영어 장면 한 줄의 설명. 지시문(운영 DB)이 아니라 스키마에 둔다 — 스키마는 코드라
  /// 배포로 바로 바뀌고, 만화 그림이 아니면 통째로 빠져 토큰도 들지 않는다.
  private static final String IMAGE_PROMPT_EN_DESCRIPTION =
    "One English sentence (under 25 words) telling the illustrator what to draw. Start with 'The character'. "
      + "Show one visible pose and the 1-2 objects held or used, placed where they are "
      + "(e.g. 'The character stands at a sink and rubs a bar of soap between both hands.'). "
      + "Always include one prop that identifies the activity (stethoscope for a check-up, pill and cup for medicine, "
      + "wallet and coins for paying). "
      + "Turn invisible actions (rest, wait, meet, arrive) into a visible pose (sits on a bench with hands on knees). "
      + "Draw only the character: never other people or animals (grandmother, friend, doctor are shown by objects only). "
      + "No background places, weather, traffic. "
      + "Never use words that cause text in the picture: exit, sign, label, menu, clock, title, card, ticket, number.";

  /// @param includeImagePromptEn 카드마다 영어 장면(imagePromptEn)을 필수로 받는다
  static Map<String, Object> responseSchema(boolean includeImagePromptEn, boolean hasPictogramCatalog) {
    // 설명 문구는 일과 언어의 사양에서 읽는다 (ko 는 사양이 기존 문장 그대로)
    ContentLanguageSpec spec = ContentLanguageSpec.of(AiCallContext.currentContentLocale());
    return Map.of(
      "type", "object",
      "properties", Map.of(
        "title", Map.of(
          "type", "string",
          "description", spec.routineTitleHint()
        ),
        "steps", Map.of(
          "type", "array",
          "maxItems", 10,
          "items", stepSchema(spec, includeImagePromptEn, hasPictogramCatalog)
        )
      ),
      "required", List.of("title", "steps")
    );
  }

  private static Map<String, Object> stepSchema(
    ContentLanguageSpec spec, boolean includeImagePromptEn, boolean hasPictogramCatalog
  ) {
    Map<String, Object> properties = new LinkedHashMap<>(Map.of(
              "order", Map.of("type", "integer"),
              "title", Map.of(
                "type", "string",
                "minLength", 1,
                "description", spec.stepTitleHint()
              ),
              "description", Map.of(
                "type", "string",
                "description", spec.stepDescriptionHint()
              )
    ));
    List<String> required = new ArrayList<>(List.of("order", "title", "description"));
    // 선택 필드다 — Gemini 는 required 에 넣지 않아 모델이 빠뜨려도 카드 생성이 실패하지 않는다.
    // 카탈로그를 못 읽은 서버는 요청·스키마 어디에도 싣지 않는다.
    if (hasPictogramCatalog) {
      properties.put("pictogramId", GeminiPictogramPickSpec.pictogramIdSchema(GeminiPictogramPickSpec.pictogramIdDescription(spec.locale())));
    }
    if (includeImagePromptEn) {
      properties.put("imagePromptEn", Map.of("type", "string", "description", IMAGE_PROMPT_EN_DESCRIPTION));
      required.add("imagePromptEn");
    }
    return Map.of("type", "object", "properties", properties, "required", required);
  }

  // 선택된 도움 목표 중 질문 생성 대상(PREPARE_ITEMS/PREPARE_NEW)의 개수만큼 questions
  // 배열 크기를 정확히 강제한다 — 목표 2개를 선택했는데 Gemini가 질문 1개만 반환하는
  // 것을 스키마 단계에서부터 막기 위함.
  static Map<String, Object> questionResponseSchemaFor(Set<SupportGoal> supportGoals) {
    int relevantGoalCount = (int) (supportGoals == null ? 0 : supportGoals.stream()
      .filter(goal -> goal == SupportGoal.PREPARE_ITEMS || goal == SupportGoal.PREPARE_NEW)
      .count());
    return Map.of(
      "type", "object",
      "properties", Map.of(
        "questions", Map.of(
          "type", "array", "minItems", relevantGoalCount, "maxItems", relevantGoalCount,
          "items", questionItemSchema()
        )
      ),
      "required", List.of("questions")
    );
  }

  // 관리자 테스트 전용: 목표 개수를 알 수 없는 임의의 프롬프트 테스트이므로 questions
  // 배열 크기를 제한하지 않는다.
  static Map<String, Object> questionResponseSchemaForTest() {
    return Map.of(
      "type", "object",
      "properties", Map.of("questions", Map.of("type", "array", "items", questionItemSchema())),
      "required", List.of("questions")
    );
  }

  // 되묻기 질문 스키마 설명: 코드라 배포하면 바로 적용 (지시문은 운영 DB)
  private static final String QUESTION_HINT = "질문 한 문장, 20자 안팎, 이름 없이";
  private static final String OPTION_LABEL_HINT = "10자 이내의 짧은 말 (문장 금지)";
  private static final String OPTION_EMOJI_HINT = "그 선택지를 나타내는 이모지 하나";

  private static Map<String, Object> questionItemSchema() {
    return Map.of(
      "type", "object",
      "properties", Map.of(
        "supportGoal", Map.of("type", "string", "enum", List.of("PREPARE_ITEMS", "PREPARE_NEW")),
        "question", Map.of("type", "string", "description", QUESTION_HINT),
        "options", Map.of(
          "type", "array",
          "minItems", 3,
          "maxItems", 5,
          "items", Map.of(
            "type", "object",
            "properties", Map.of(
              "emoji", Map.of("type", "string", "description", OPTION_EMOJI_HINT),
              "label", Map.of("type", "string", "description", OPTION_LABEL_HINT)
            ),
            "required", List.of("emoji", "label")
          )
        )
      ),
      "required", List.of("supportGoal", "question", "options")
    );
  }
}
