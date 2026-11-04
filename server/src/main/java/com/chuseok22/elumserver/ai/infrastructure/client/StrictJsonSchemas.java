package com.chuseok22.elumserver.ai.infrastructure.client;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Gemini 스키마 > strict JSON 스키마 변환 (OpenAI·Claude 공통)
 * 둘 다 모든 객체에 additionalProperties:false·전 필드 required 를 요구하고 길이 제약을 받지 않는다
 */
final class StrictJsonSchemas {

  private StrictJsonSchemas() {
  }

  /**
   * Gemini 스키마 한 벌을 strict JSON 스키마(OpenAI json_schema strict · Claude output_config.format)로 옮긴다.
   *
   * <p><b>스키마를 두 벌로 나누지 않는 이유.</b> 일과 카드의 형태(제목·단계·설명)는
   * 제공자와 무관한 서비스 규칙이다. 두 곳에 적어 두면 한쪽만 고쳐져 제공자를 바꾼
   * 순간 카드 모양이 달라진다.
   *
   * <p>세 가지를 맞춘다 — strict 모드는 (1) 모든 객체에
   * {@code additionalProperties:false}를 요구하고, (2) {@code required}에 모든
   * 프로퍼티가 들어 있어야 하며, (3) {@code minItems} 같은 길이 제약을 받지 않는다.
   * 길이 제약은 버리는 것이 아니라 <b>프롬프트에 이미 적혀 있다</b> — 스키마로 두 번
   * 강제하던 것을 한 겹 잃을 뿐이라, 질문 개수가 모자라면 기존 목표별 fallback이 받는다.
   */
  static Map<String, Object> from(Map<String, Object> source) {
    Map<String, Object> converted = new LinkedHashMap<>();
    for (Map.Entry<String, Object> entry : source.entrySet()) {
      String key = entry.getKey();
      if (UNSUPPORTED_KEYWORDS.contains(key)) {
        continue;
      }
      converted.put(key, convertValue(entry.getValue()));
    }
    // Gemini 의 nullable:true 는 strict 스키마에 없는 키워드다 — 그대로 두면 400. type 을 [기존 type, "null"] 로 바꾼다.
    // (pictogramId 처럼 선택 필드도 strict 는 required 에 넣어야 하므로 null 을 허용하는 것이 유일한 "비워 둠"이다.)
    if (Boolean.TRUE.equals(converted.remove("nullable")) && converted.get("type") instanceof String type) {
      converted.put("type", List.of(type, "null"));
    }
    if ("object".equals(source.get("type"))) {
      Object properties = converted.get("properties");
      if (properties instanceof Map<?, ?> propertyMap) {
        converted.put("required", new ArrayList<>(propertyMap.keySet()));
      }
      converted.put("additionalProperties", false);
    }
    return converted;
  }

  @SuppressWarnings("unchecked")
  private static Object convertValue(Object value) {
    if (value instanceof Map<?, ?> map) {
      return from((Map<String, Object>) map);
    }
    if (value instanceof List<?> list) {
      return list.stream().map(StrictJsonSchemas::convertValue).toList();
    }
    return value;
  }

  /// strict 모드가 받지 않는 키워드. 남겨 두면 400으로 호출 자체가 실패한다.
  private static final Set<String> UNSUPPORTED_KEYWORDS =
    Set.of("minItems", "maxItems", "minLength", "maxLength");

}
