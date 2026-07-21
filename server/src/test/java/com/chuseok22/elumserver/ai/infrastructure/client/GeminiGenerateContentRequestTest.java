package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class GeminiGenerateContentRequestTest {

  private final ObjectMapper objectMapper = new ObjectMapper();

  @Test
  @DisplayName("텍스트만 있는 GeminiPart는 inlineData 없이 직렬화된다")
  void geminiPart_textOnly_serializesWithoutInlineData() throws Exception {
    GeminiGenerateContentRequest.GeminiPart part =
      new GeminiGenerateContentRequest.GeminiPart("설명 텍스트");

    String json = objectMapper.writeValueAsString(part);

    assertThat(json).contains("\"text\":\"설명 텍스트\"");
    assertThat(json).doesNotContain("inlineData");
  }

  @Test
  @DisplayName("캐릭터 참조 이미지 GeminiPart는 text 없이 inlineData만 직렬화된다")
  void geminiPart_inlineData_serializesWithoutText() throws Exception {
    GeminiGenerateContentRequest.GeminiPart part =
      GeminiGenerateContentRequest.GeminiPart.ofInlineData("image/png", "base64data");

    String json = objectMapper.writeValueAsString(part);

    assertThat(json).contains("\"inlineData\":{\"mimeType\":\"image/png\",\"data\":\"base64data\"}");
    assertThat(json).doesNotContain("\"text\"");
  }
}
