package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * Gemini 스키마 → OpenAI strict 스키마 변환.
 *
 * <p>여기가 어긋나면 OpenAI 호출이 400으로 <b>전부</b> 실패한다. 제공자를 바꾼 뒤에야
 * 드러나는 종류의 고장이라 변환 규칙만 따로 못박아 둔다.
 */
class OpenAiTextClientSchemaTest {

  @SuppressWarnings("unchecked")
  private static List<String> stringList(Object value) {
    return (List<String>) value;
  }

  @Test
  @DisplayName("객체마다 additionalProperties=false를 붙이고 required를 전체 프로퍼티로 채운다")
  void objectBecomesStrict() {
    Map<String, Object> source = Map.of(
      "type", "object",
      "properties", Map.of(
        "title", Map.of("type", "string"),
        "steps", Map.of("type", "array", "items", Map.of("type", "string"))
      ),
      // 원본은 title만 필수로 적혀 있다 — strict 모드는 전부 필수여야 한다.
      "required", List.of("title")
    );

    Map<String, Object> converted = OpenAiTextClient.toStrictSchema(source);

    assertThat(converted.get("additionalProperties")).isEqualTo(false);
    assertThat(stringList(converted.get("required")))
      .containsExactlyInAnyOrder("title", "steps");
  }

  @Test
  @DisplayName("strict 모드가 받지 않는 길이 제약은 걷어낸다 — 남겨두면 400이 난다")
  void dropsUnsupportedKeywords() {
    Map<String, Object> source = Map.of(
      "type", "object",
      "properties", Map.of(
        "questions", Map.of(
          "type", "array",
          "minItems", 2,
          "maxItems", 2,
          "items", Map.of(
            "type", "object",
            "properties", Map.of("label", Map.of("type", "string", "minLength", 1)),
            "required", List.of("label")
          )
        )
      ),
      "required", List.of("questions")
    );

    Map<String, Object> converted = OpenAiTextClient.toStrictSchema(source);

    @SuppressWarnings("unchecked")
    Map<String, Object> questions =
      (Map<String, Object>) ((Map<String, Object>) converted.get("properties")).get("questions");
    assertThat(questions).doesNotContainKeys("minItems", "maxItems");

    @SuppressWarnings("unchecked")
    Map<String, Object> label = (Map<String, Object>)
      ((Map<String, Object>) ((Map<String, Object>) questions.get("items")).get("properties")).get("label");
    assertThat(label).doesNotContainKey("minLength");
  }

  @Test
  @DisplayName("배열 안에 중첩된 객체에도 규칙이 그대로 적용된다")
  void appliesRecursivelyIntoArrayItems() {
    Map<String, Object> source = Map.of(
      "type", "object",
      "properties", Map.of(
        "steps", Map.of(
          "type", "array",
          "items", Map.of(
            "type", "object",
            "properties", Map.of(
              "order", Map.of("type", "integer"),
              "title", Map.of("type", "string")
            ),
            "required", List.of("order")
          )
        )
      ),
      "required", List.of("steps")
    );

    Map<String, Object> converted = OpenAiTextClient.toStrictSchema(source);

    @SuppressWarnings("unchecked")
    Map<String, Object> items = (Map<String, Object>)
      ((Map<String, Object>) ((Map<String, Object>) converted.get("properties")).get("steps")).get("items");
    assertThat(items.get("additionalProperties")).isEqualTo(false);
    assertThat(stringList(items.get("required"))).containsExactlyInAnyOrder("order", "title");
  }

  @Test
  @DisplayName("description·enum 같은 설명 정보는 그대로 남긴다 — 모델에게 주는 지시다")
  void keepsDescriptiveKeywords() {
    Map<String, Object> source = Map.of(
      "type", "object",
      "properties", Map.of(
        "supportGoal", Map.of(
          "type", "string",
          "description", "도움 목표",
          "enum", List.of("PREPARE_ITEMS", "PREPARE_NEW")
        )
      ),
      "required", List.of("supportGoal")
    );

    Map<String, Object> converted = OpenAiTextClient.toStrictSchema(source);

    @SuppressWarnings("unchecked")
    Map<String, Object> goal = (Map<String, Object>)
      ((Map<String, Object>) converted.get("properties")).get("supportGoal");
    assertThat(goal.get("description")).isEqualTo("도움 목표");
    assertThat(stringList(goal.get("enum"))).containsExactly("PREPARE_ITEMS", "PREPARE_NEW");
  }

  @Test
  @DisplayName("nullable string(pictogramId)은 strict 규격의 type [string, null] 로 바뀌고 nullable 키는 사라진다 — 남기면 400")
  void nullableStringBecomesTypeUnion() {
    Map<String, Object> source = Map.of(
      "type", "object",
      "properties", Map.of(
        "pictogramId", Map.of("type", "string", "nullable", true, "description", "고르세요")
      ),
      "required", List.of()
    );

    Map<String, Object> converted = OpenAiTextClient.toStrictSchema(source);

    @SuppressWarnings("unchecked")
    Map<String, Object> field = (Map<String, Object>) ((Map<String, Object>) converted.get("properties")).get("pictogramId");
    assertThat(field.get("type")).isEqualTo(List.of("string", "null"));
    assertThat(field).doesNotContainKey("nullable").doesNotContainKey("enum");
    assertThat(field.get("description")).isEqualTo("고르세요");
    // strict 는 선택 필드도 required 에 넣어야 하므로 null 허용이 "비워 둠"의 유일한 길이다.
    assertThat(stringList(converted.get("required"))).contains("pictogramId");
  }

  @Test
  @DisplayName("nullable 이 아닌 string 은 그대로 둔다")
  void plainStringIsUntouched() {
    Map<String, Object> converted = OpenAiTextClient.toStrictSchema(Map.of("type", "string"));

    assertThat(converted.get("type")).isEqualTo("string");
  }
}
