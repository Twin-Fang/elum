package com.chuseok22.elumserver.common.infrastructure.properties;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 내부 AI 서버 접속값: 음성 합성(Supertonic TTS)이 사용
 * baseUrl 비면 기본 주소
 */
@ConfigurationProperties(prefix = "local-llm")
public record LocalLlmProperties(
  String baseUrl,
  String apiKey
) {

  private static final String DEFAULT_BASE_URL = "https://ai.suhsaechan.kr";

  public LocalLlmProperties {
    if (baseUrl == null || baseUrl.isBlank()) {
      baseUrl = DEFAULT_BASE_URL;
    }
  }
}
