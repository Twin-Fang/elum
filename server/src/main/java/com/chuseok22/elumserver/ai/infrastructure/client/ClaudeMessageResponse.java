package com.chuseok22.elumserver.ai.infrastructure.client;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

/**
 * Claude Messages API 응답 중 쓰는 것만: 본문 블록, 멈춘 이유, 토큰 수 (모르는 필드는 무시)
 * 생각(thinking) 블록은 건너뛰고 text 블록 하나를 JSON 본문으로 씀
 */
@JsonIgnoreProperties(ignoreUnknown = true)
record ClaudeMessageResponse(
  List<ContentBlock> content,
  @JsonProperty("stop_reason") String stopReason,
  Usage usage
) {

  // stop_reason: 끝까지 씀 / 안전 거절 / 최대 토큰에서 잘림
  private static final String STOP_REFUSAL = "refusal";
  private static final String STOP_MAX_TOKENS = "max_tokens";
  private static final String TEXT_BLOCK_TYPE = "text";

  /// 응답 > JSON 본문 문자열 (거절·잘림·빈 본문은 던짐 > 같은 키로 다시 해도 같아서 다음 제공자로)
  static String extractJsonText(ClaudeMessageResponse response) {
    if (response == null || response.content() == null) {
      throw new IllegalStateException("Claude 응답에 본문이 없음");
    }
    if (STOP_REFUSAL.equals(response.stopReason())) {
      throw new IllegalStateException("Claude 가 안전 사유로 거절함 (stop_reason=refusal)");
    }
    if (STOP_MAX_TOKENS.equals(response.stopReason())) {
      throw new IllegalStateException("Claude 응답이 최대 토큰에서 잘림 (stop_reason=max_tokens)");
    }
    return response.content().stream()
      .filter(block -> block != null && TEXT_BLOCK_TYPE.equals(block.type()))
      .map(ContentBlock::text)
      .filter(text -> text != null && !text.isBlank())
      .findFirst()
      .orElseThrow(() -> new IllegalStateException("Claude 응답 본문이 비어 있음"));
  }

  /**
   * 토큰 수 > 기존 기록 형식(Gemini UsageMetadata). 입력 = 일반 + 캐시 읽기 + 캐시 쓰기, 출력은 생각 토큰 포함
   * 제공자마다 기록 형식을 따로 두면 관리자 비용 화면이 제공자 수만큼 갈라짐 (OpenAiTextClient 와 같은 방침)
   */
  GeminiGenerateContentResponse.UsageMetadata toUsageMetadata() {
    if (usage == null) {
      return null;
    }
    int inputTokens = orZero(usage.inputTokens()) + orZero(usage.cacheReadInputTokens())
      + orZero(usage.cacheCreationInputTokens());
    int outputTokens = orZero(usage.outputTokens());
    return new GeminiGenerateContentResponse.UsageMetadata(inputTokens, outputTokens, inputTokens + outputTokens);
  }

  private static int orZero(Integer tokens) {
    return tokens == null ? 0 : tokens;
  }

  @JsonIgnoreProperties(ignoreUnknown = true)
  record ContentBlock(String type, String text) {

  }

  @JsonIgnoreProperties(ignoreUnknown = true)
  record Usage(
    @JsonProperty("input_tokens") Integer inputTokens,
    @JsonProperty("output_tokens") Integer outputTokens,
    @JsonProperty("cache_read_input_tokens") Integer cacheReadInputTokens,
    @JsonProperty("cache_creation_input_tokens") Integer cacheCreationInputTokens
  ) {

  }
}
