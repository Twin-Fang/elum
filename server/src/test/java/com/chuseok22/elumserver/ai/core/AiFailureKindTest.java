package com.chuseok22.elumserver.ai.core;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 실패 문구 분류: 운영 실패 기록에 실제로 남은 문구 기준
 * 깨지면 크레딧 소진이 "한도 초과"로 보여 관리자가 충전 시점을 놓친다
 */
class AiFailureKindTest {

  @Test
  @DisplayName("OpenAI 크레딧 소진은 429 로 와도 크레딧·결제로 분류한다")
  void creditExhaustionBeatsRateLimit() {
    String message = "429 Too Many Requests: \"{\n    \"error\": {\n        \"message\": \"You have no credits remaining. "
      + "Add credits to continue using the API";

    assertThat(AiFailureKind.classify(message)).isEqualTo(AiFailureKind.CREDIT);
  }

  @Test
  @DisplayName("분당 한도 초과·키 오류·안전 필터·제공자 장애를 각각 가른다")
  void classifiesOtherProductionMessages() {
    assertThat(AiFailureKind.classify("429 Too Many Requests: \"{ \"error\": { \"message\": \"Rate limit reached for gpt-image-1-mini"))
      .isEqualTo(AiFailureKind.RATE_LIMIT);
    assertThat(AiFailureKind.classify("401 Unauthorized: [no body]")).isEqualTo(AiFailureKind.KEY);
    assertThat(AiFailureKind.classify("400 Bad Request: \"{ \"error\": { \"message\": \"Your request was rejected by the safety system"))
      .isEqualTo(AiFailureKind.SAFETY);
    assertThat(AiFailureKind.classify("503 Service Unavailable: \"{ \"error\": { \"code\": 503"))
      .isEqualTo(AiFailureKind.PROVIDER_DOWN);
    assertThat(AiFailureKind.classify(null)).isEqualTo(AiFailureKind.OTHER);
  }
}
