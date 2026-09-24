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
  //
  // thoughtsTokenCount — 2.5 계열은 답하기 전에 "생각"하고 그 토큰을 출력 단가로 청구한다.
  // candidatesTokenCount 에는 들어 있지 않아, 예전에는 기록과 비용 추정에서 통째로 빠졌다 (#375).
  // 생각하지 않은 호출·다른 제공자는 null 이다.
  @JsonIgnoreProperties(ignoreUnknown = true)
  public record UsageMetadata(
    Integer promptTokenCount, Integer candidatesTokenCount, Integer totalTokenCount,
    Integer thoughtsTokenCount
  ) {

    // 생각 토큰이 없는 제공자(OpenAI 글·그림)가 옮겨 담을 때 쓴다.
    public UsageMetadata(Integer promptTokenCount, Integer candidatesTokenCount, Integer totalTokenCount) {
      this(promptTokenCount, candidatesTokenCount, totalTokenCount, null);
    }

    /// 청구되는 출력 토큰 — 답 + 생각. 둘 다 없으면 null(기록하지 않음).
    public Integer billableOutputTokens() {
      if (candidatesTokenCount == null && thoughtsTokenCount == null) {
        return null;
      }
      return (candidatesTokenCount == null ? 0 : candidatesTokenCount)
        + (thoughtsTokenCount == null ? 0 : thoughtsTokenCount);
    }
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
