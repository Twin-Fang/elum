package com.chuseok22.elumserver.ai.infrastructure.client;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.util.List;

// Gemini 응답에는 여기서 쓰지 않는 필드(finishReason, safetyRatings 등)가 더 있으므로
// 알 수 없는 필드는 무시한다.
@JsonIgnoreProperties(ignoreUnknown = true)
public record GeminiGenerateContentResponse(List<Candidate> candidates, UsageMetadata usageMetadata) {

  // usageMetadata를 쓰지 않는 기존 테스트/호출부 호환용.
  public GeminiGenerateContentResponse(List<Candidate> candidates) {
    this(candidates, null);
  }

  @JsonIgnoreProperties(ignoreUnknown = true)
  public record Candidate(Content content) {

  }

  // 토큰 사용량(AI 호출 로그의 비용 계산 원천). Gemini가 usageMetadata를 생략해도
  // 역직렬화가 깨지지 않도록 박싱 타입을 쓴다.
  @JsonIgnoreProperties(ignoreUnknown = true)
  public record UsageMetadata(Integer promptTokenCount, Integer candidatesTokenCount, Integer totalTokenCount) {

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
