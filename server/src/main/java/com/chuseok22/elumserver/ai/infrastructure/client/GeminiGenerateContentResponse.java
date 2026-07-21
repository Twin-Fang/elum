package com.chuseok22.elumserver.ai.infrastructure.client;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.util.List;

// Gemini 응답에는 여기서 쓰지 않는 필드(finishReason, safetyRatings 등)가 더 있으므로
// 알 수 없는 필드는 무시한다.
@JsonIgnoreProperties(ignoreUnknown = true)
public record GeminiGenerateContentResponse(List<Candidate> candidates) {

  @JsonIgnoreProperties(ignoreUnknown = true)
  public record Candidate(Content content) {

  }

  @JsonIgnoreProperties(ignoreUnknown = true)
  public record Content(List<Part> parts) {

  }

  @JsonIgnoreProperties(ignoreUnknown = true)
  public record Part(String text, InlineData inlineData) {

  }

  @JsonIgnoreProperties(ignoreUnknown = true)
  public record InlineData(String mimeType, String data) {

  }
}
