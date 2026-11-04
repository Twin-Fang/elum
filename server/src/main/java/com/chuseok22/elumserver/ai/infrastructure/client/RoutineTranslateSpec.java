package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.core.NicknamePlaceholder;
import com.chuseok22.elumserver.ai.core.RoutineTranslationDraft;
import com.chuseok22.elumserver.common.infrastructure.json.DefaultJsonMapper;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.fasterxml.jackson.core.JsonProcessingException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 일과 번역 요청 사양 (#1077): 시스템 지시문, 입력 JSON, 응답 스키마 (단계 수 고정)
 * 지시문은 운영 DB 가 아니라 코드에 둠 (배포로 바로 바뀜, 관리자 화면에서 실수로 지울 수 없음 — 픽토그램 고르기와 같음)
 * 모든 텍스트 제공자가 같은 문장을 공유 (제공자를 바꿔도 비교 가능)
 */
final class RoutineTranslateSpec {

  private RoutineTranslateSpec() {
  }

  // 응답 필드
  static final String TITLE_FIELD = "title";
  static final String REWARD_TEXT_FIELD = "rewardText";
  static final String STEPS_FIELD = "steps";
  static final String STEP_TITLE_FIELD = "title";
  static final String STEP_DESCRIPTION_FIELD = "description";

  /// 지시문 틀: %1$s 대상 언어 이름, %2$s 원문 언어 이름, %3$s 원문 자리표시, %4$s 대상 자리표시, %5$s 대상 언어 말투 규칙
  private static final String SYSTEM_PROMPT_TEMPLATE = """
    You translate a picture-card routine for children with developmental disabilities from %2$s into %1$s.
    The input JSON has routine.title, routine.rewardText (may be null) and routine.steps in order.
    Rules:
    - Translate the meaning faithfully. Do not add, remove, merge, split or reorder steps. \
    Return exactly stepCount steps in the same order.
    - Keep every sentence short, concrete and easy, as it is read aloud to a child. \
    One action per card description, friendly instruction tone.
    - Card titles are short labels of a few words. If a step title is null or empty, write a short title from its description.
    - The child's name is replaced by the placeholder "%3$s". Write it as "%4$s" in the output, unchanged.
    - If routine.rewardText is null, return null for rewardText.
    - Write only %1$s. Do not add romanization, notes or the original text.
    %5$s""";

  /// ko 대상 말투 (서비스 문구 규칙: 해요체·능동형·긍정형)
  private static final String KOREAN_TONE_RULE =
    "- Write Korean in polite 해요체, active and positive (e.g. \"손을 씻어요\").";

  static String systemPrompt(AppLocale sourceLanguage, AppLocale targetLanguage) {
    return SYSTEM_PROMPT_TEMPLATE.formatted(
      languageName(targetLanguage), languageName(sourceLanguage),
      NicknamePlaceholder.placeholderFor(sourceLanguage), NicknamePlaceholder.placeholderFor(targetLanguage),
      targetLanguage == AppLocale.KO ? KOREAN_TONE_RULE : "");
  }

  /// 입력 JSON: 작업 이름, 원문·대상 언어 코드, 단계 수, 일과 글 (보호자 원문·이름 없음)
  static String userContent(RoutineTranslationDraft draft, AppLocale sourceLanguage, AppLocale targetLanguage) {
    List<Map<String, Object>> steps = new ArrayList<>();
    for (RoutineTranslationDraft.StepText step : draft.steps()) {
      Map<String, Object> stepInput = new LinkedHashMap<>();
      stepInput.put(STEP_TITLE_FIELD, step.title());
      stepInput.put(STEP_DESCRIPTION_FIELD, step.description());
      steps.add(stepInput);
    }
    Map<String, Object> routine = new LinkedHashMap<>();
    routine.put(TITLE_FIELD, draft.title());
    routine.put(REWARD_TEXT_FIELD, draft.rewardText());
    routine.put(STEPS_FIELD, steps);
    Map<String, Object> input = new LinkedHashMap<>();
    input.put("task", "TRANSLATE_ROUTINE");
    input.put("sourceLanguage", sourceLanguage.code());
    input.put("targetLanguage", targetLanguage.code());
    input.put("stepCount", steps.size());
    input.put("routine", routine);
    try {
      return DefaultJsonMapper.SHARED.writeValueAsString(input);
    } catch (JsonProcessingException e) {
      throw new IllegalStateException("번역 요청 JSON 직렬화 실패", e);
    }
  }

  /// 응답 스키마: 제목, 보상(없으면 null), 단계 배열 (원문 단계 수로 길이 고정 — strict 규격은 길이 제약을 버림 > 받은 뒤 서버가 다시 셈)
  static Map<String, Object> schema(int stepCount) {
    Map<String, Object> stepSchema = Map.of(
      "type", "object",
      "properties", Map.of(
        STEP_TITLE_FIELD, Map.of("type", "string"),
        STEP_DESCRIPTION_FIELD, Map.of("type", "string")
      ),
      "required", List.of(STEP_TITLE_FIELD, STEP_DESCRIPTION_FIELD)
    );
    Map<String, Object> properties = new LinkedHashMap<>();
    properties.put(TITLE_FIELD, Map.of("type", "string"));
    properties.put(REWARD_TEXT_FIELD, Map.of("type", "string", "nullable", true));
    properties.put(STEPS_FIELD, Map.of(
      "type", "array", "items", stepSchema, "minItems", stepCount, "maxItems", stepCount));
    return Map.of(
      "type", "object",
      "properties", properties,
      "required", List.of(TITLE_FIELD, REWARD_TEXT_FIELD, STEPS_FIELD)
    );
  }

  /// 지시문에 쓰는 언어 이름 (중국어는 앱이 간체만 지원)
  static String languageName(AppLocale locale) {
    return switch (locale) {
      case KO -> "Korean";
      case EN -> "English";
      case JA -> "Japanese";
      case ZH -> "Simplified Chinese";
      case ES -> "Spanish";
    };
  }
}
