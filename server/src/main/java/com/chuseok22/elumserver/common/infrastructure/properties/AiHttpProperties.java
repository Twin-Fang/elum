package com.chuseok22.elumserver.common.infrastructure.properties;

import org.springframework.boot.context.properties.ConfigurationProperties;

/// OpenAI·FLUX 호출이 공유하는 HTTP 제한 시간(ms).
@ConfigurationProperties(prefix = "ai.http")
public record AiHttpProperties(
  Long connectTimeoutMillis,
  Long readTimeoutMillis
) {

  public static final long DEFAULT_CONNECT_TIMEOUT_MILLIS = 10_000;
  // 이미지·텍스트 생성은 수십 초가 걸린다. 읽기 제한을 넉넉히 두되 무한 대기는 막는다.
  public static final long DEFAULT_READ_TIMEOUT_MILLIS = 120_000;

  // yml에 키가 없거나 0 이하여도 기동이 막히거나 무한 대기가 되지 않도록 기본값으로 보정한다.
  public AiHttpProperties {
    if (connectTimeoutMillis == null || connectTimeoutMillis <= 0) {
      connectTimeoutMillis = DEFAULT_CONNECT_TIMEOUT_MILLIS;
    }
    if (readTimeoutMillis == null || readTimeoutMillis <= 0) {
      readTimeoutMillis = DEFAULT_READ_TIMEOUT_MILLIS;
    }
  }
}
