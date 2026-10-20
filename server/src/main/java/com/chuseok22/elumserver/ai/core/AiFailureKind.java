package com.chuseok22.elumserver.ai.core;

import java.util.List;
import java.util.Locale;
import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * AI 호출 실패 문구 > 원인 분류 (운영 실패 기록 실측 문구 기준, 위에서부터 첫 일치)
 * 크레딧 소진도 OpenAI 는 429 로 오므로 크레딧 문구를 한도 초과보다 먼저 본다
 */
@Getter
@AllArgsConstructor
public enum AiFailureKind {

  // 예: 429 "You have no credits remaining", insufficient_quota
  CREDIT("크레딧·결제", List.of("no credits", "insufficient_quota", "exceeded your current quota",
    "billing", "balance", "402")),
  KEY("키·권한", List.of("401", "403")),
  RATE_LIMIT("한도 초과", List.of("429", "rate limit", "resource_exhausted")),
  SAFETY("안전 필터 거절", List.of("safety")),
  PROVIDER_DOWN("제공자 장애", List.of("500", "502", "503", "504", "unavailable")),
  TIMEOUT("시간 초과", List.of("timeout", "timed out")),
  OTHER("기타", List.of()),
  ;

  private final String label;
  /// 소문자 비교용 포함 문구
  private final List<String> markers;

  /** 실패 문구 > 분류 (비어 있으면 기타) */
  public static AiFailureKind classify(String errorMessage) {
    if (errorMessage == null || errorMessage.isBlank()) {
      return OTHER;
    }
    String lowered = errorMessage.toLowerCase(Locale.ROOT);
    for (AiFailureKind kind : values()) {
      if (kind.markers.stream().anyMatch(lowered::contains)) {
        return kind;
      }
    }
    return OTHER;
  }
}
