package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.ai.core.AiCallType;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * OpenAI 글 생성 요청 본문 (#411).
 *
 * <p>Chat Completions 는 store 를 빼면 대시보드 Logs 에 아무것도 남지 않는다. 빠져도 호출은
 * 멀쩡히 성공하므로 누가 본문을 손보다 지워도 알아챌 길이 없어 여기서 못박는다.
 */
class OpenAiTextClientRequestBodyTest {

  private static final Map<String, Object> SCHEMA = Map.of(
    "type", "object",
    "properties", Map.of("title", Map.of("type", "string")),
    "required", List.of("title")
  );

  @Test
  @DisplayName("대시보드 Logs 에 남도록 store=true 를 보낸다")
  void storesForDashboardLogs() {
    Map<String, Object> body = OpenAiTextClient.buildRequestBody(
      "gpt-5-mini", "system", "user", SCHEMA, "routine", AiCallType.OPENAI_TEXT_CREATE
    );

    assertThat(body.get("store")).isEqualTo(true);
  }

  @Test
  @DisplayName("대시보드에서 호출 종류로 거를 수 있게 metadata 에 call_type 을 붙인다")
  void tagsCallTypeInMetadata() {
    Map<String, Object> create = OpenAiTextClient.buildRequestBody(
      "gpt-5-mini", "system", "user", SCHEMA, "routine", AiCallType.OPENAI_TEXT_CREATE
    );
    Map<String, Object> question = OpenAiTextClient.buildRequestBody(
      "gpt-5-mini", "system", "user", SCHEMA, "routine_questions", AiCallType.OPENAI_TEXT_QUESTION
    );

    assertThat(create.get("metadata")).isEqualTo(Map.of("call_type", "OPENAI_TEXT_CREATE"));
    assertThat(question.get("metadata")).isEqualTo(Map.of("call_type", "OPENAI_TEXT_QUESTION"));
  }

  @Test
  @DisplayName("기존 필드(model·messages·response_format)는 그대로 보내고 temperature 는 보내지 않는다")
  void keepsExistingFields() {
    Map<String, Object> body = OpenAiTextClient.buildRequestBody(
      "gpt-5-mini", "system", "user", SCHEMA, "routine", AiCallType.OPENAI_TEXT_CREATE
    );

    assertThat(body.get("model")).isEqualTo("gpt-5-mini");
    assertThat(body).containsKeys("messages", "response_format");
    assertThat(body).doesNotContainKey("temperature");
  }
}
