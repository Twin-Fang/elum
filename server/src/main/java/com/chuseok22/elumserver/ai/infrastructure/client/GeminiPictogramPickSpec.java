package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.common.locale.AppLocale;
import java.util.List;
import java.util.Map;

/**
 * 픽토그램 고르기 요청 사양: 시스템 지시문, id 설명, 응답 스키마 (ko <-> 그 밖의 언어)
 * Gemini 와 OpenAI 텍스트 클라이언트가 같은 문장을 공유 (제공자를 바꿔도 비교 가능)
 */
final class GeminiPictogramPickSpec {

  private GeminiPictogramPickSpec() {
  }

  static final String PICTOGRAM_PICK_SYSTEM_PROMPT =
    "당신은 발달장애인용 행동 카드에 붙일 픽토그램을 고르는 도우미입니다. "
      + "입력의 stepTitle·stepDescription 이 나타내는 행동이나 사물을 가장 잘 나타내는 픽토그램 id 를 "
      + "pictogramCatalog 안에서 하나만 고르세요. "
      + "알맞은 것이 없거나 확신이 없으면 null 을 주세요. 억지로 고르지 마세요(비슷하지만 뜻이 다른 것은 금지).";

  /// ko 가 아닌 일과용: 같은 규칙을 영어로 쓰고 입력은 어떤 언어든 뜻으로 맞추게 한다
  static final String PICTOGRAM_PICK_SYSTEM_PROMPT_GLOBAL =
    "You choose a pictogram for an action card for people with developmental disabilities. "
      + "From pictogramCatalog, pick exactly one pictogram id that best shows the action or object that "
      + "stepTitle and stepDescription describe. They may be written in any language; match by meaning. "
      + "If nothing fits or you are not sure, return null. Do not force a pick "
      + "(never choose something similar but with a different meaning).";

  static String pictogramPickSystemPrompt(AppLocale locale) {
    return locale == AppLocale.KO ? PICTOGRAM_PICK_SYSTEM_PROMPT : PICTOGRAM_PICK_SYSTEM_PROMPT_GLOBAL;
  }

  /// 카드 그림 id 의 설명. 지시는 여기(코드)에 둔다 — 프롬프트는 운영 DB 값이라 배포로 안 바뀐다.
  static final String PICTOGRAM_ID_DESCRIPTION =
    "pictogramCatalog 안에서 이 단계의 행동이나 사물을 가장 잘 나타내는 id 하나. "
      + "알맞은 것이 없거나 확신이 없으면 null. 억지로 고르지 마세요(비슷하지만 뜻이 다른 것 금지)";

  static final String PICTOGRAM_ID_DESCRIPTION_GLOBAL =
    "One id from pictogramCatalog that best shows this step's action or object. "
      + "null if nothing fits or you are not sure. Do not force a pick (similar but different meaning is forbidden)";

  static String pictogramIdDescription(AppLocale locale) {
    return locale == AppLocale.KO ? PICTOGRAM_ID_DESCRIPTION : PICTOGRAM_ID_DESCRIPTION_GLOBAL;
  }

  // nullable string — enum 으로 만들지 않는다(값이 811개라 스키마가 비대해진다). 검증은 응답을 받은 뒤 서버가 한다.
  static Map<String, Object> pictogramIdSchema(String description) {
    return Map.of("type", "string", "nullable", true, "description", description);
  }

  static Map<String, Object> pictogramPickSchema() {
    return PICTOGRAM_PICK_SCHEMA;
  }

  static Map<String, Object> pictogramPickSchema(AppLocale locale) {
    return locale == AppLocale.KO ? PICTOGRAM_PICK_SCHEMA : PICTOGRAM_PICK_SCHEMA_GLOBAL;
  }

  private static Map<String, Object> pictogramPickSchemaOf(String idDescription) {
    return Map.of(
      "type", "object",
      "properties", Map.of("pictogramId", pictogramIdSchema(idDescription)),
      "required", List.of("pictogramId")
    );
  }

  private static final Map<String, Object> PICTOGRAM_PICK_SCHEMA = pictogramPickSchemaOf(PICTOGRAM_ID_DESCRIPTION);

  private static final Map<String, Object> PICTOGRAM_PICK_SCHEMA_GLOBAL =
    pictogramPickSchemaOf(PICTOGRAM_ID_DESCRIPTION_GLOBAL);
}
