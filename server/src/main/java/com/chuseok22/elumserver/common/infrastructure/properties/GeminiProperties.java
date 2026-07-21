package com.chuseok22.elumserver.common.infrastructure.properties;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "gemini")
public record GeminiProperties(
  String apiKey,
  String baseUrl,
  String textModel,
  String imageModel,
  long timeoutMillis
) {

  private static final String DEFAULT_BASE_URL = "https://generativelanguage.googleapis.com";
  private static final long DEFAULT_TIMEOUT_MILLIS = 30000;

  // application-dev.yml/application-prod.yml에 gemini 섹션이 없거나 timeoutMillis를
  // 생략해도 GeminiConfig의 RestClient Bean 생성이 실패해 애플리케이션 전체가 기동하지
  // 못하는 일이 없도록 기본값을 보정한다.
  public GeminiProperties {
    if (baseUrl == null || baseUrl.isBlank()) {
      baseUrl = DEFAULT_BASE_URL;
    }
    if (timeoutMillis <= 0) {
      timeoutMillis = DEFAULT_TIMEOUT_MILLIS;
    }
  }
}
