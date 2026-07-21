package com.chuseok22.elumserver.common.infrastructure.properties;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "local-llm")
public record LocalLlmProperties(
  boolean enabled,
  String baseUrl,
  String chatPath,
  String apiKey,
  String model,
  long timeoutMillis
) {

  private static final String DEFAULT_BASE_URL = "https://ai.suhsaechan.kr";
  private static final long DEFAULT_TIMEOUT_MILLIS = 15000;

  // application-dev.yml/application-prod.yml에 local-llm 섹션이 아직 등록되지 않았거나
  // timeoutMillis를 생략한 경우에도 LocalLlmConfig의 RestClient Bean 생성이
  // (Duration.ZERO 등으로) 실패해 애플리케이션 전체가 기동하지 못하는 일이 없도록
  // 기본값을 보정한다. enabled=false면 어차피 이 값들로 실제 호출을 하지 않는다.
  public LocalLlmProperties {
    if (baseUrl == null || baseUrl.isBlank()) {
      baseUrl = DEFAULT_BASE_URL;
    }
    if (timeoutMillis <= 0) {
      timeoutMillis = DEFAULT_TIMEOUT_MILLIS;
    }
  }
}
