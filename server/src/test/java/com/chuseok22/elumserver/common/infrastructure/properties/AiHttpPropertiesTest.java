package com.chuseok22.elumserver.common.infrastructure.properties;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.ai.infrastructure.client.AiRestClientFactory;
import java.time.Duration;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 설정이 없을 때의 제한 시간이 기존 하드코딩 값(연결 10초 · 읽기 120초)과 같아야 동작이 바뀌지 않는다.
class AiHttpPropertiesTest {

  @Test
  @DisplayName("키를 주지 않으면 연결 10초 · 읽기 120초")
  void defaults_matchLegacyValues() {
    AiHttpProperties properties = new AiHttpProperties(null, null);

    assertThat(Duration.ofMillis(properties.connectTimeoutMillis())).isEqualTo(Duration.ofSeconds(10));
    assertThat(Duration.ofMillis(properties.readTimeoutMillis())).isEqualTo(Duration.ofSeconds(120));
  }

  @Test
  @DisplayName("0 이하 값은 기본값으로 보정하고, 양수는 그대로 쓴다")
  void invalidValues_fallBackToDefaults() {
    assertThat(new AiHttpProperties(0L, -1L))
      .isEqualTo(new AiHttpProperties(null, null));

    AiHttpProperties custom = new AiHttpProperties(5_000L, 60_000L);
    assertThat(custom.connectTimeoutMillis()).isEqualTo(5_000L);
    assertThat(custom.readTimeoutMillis()).isEqualTo(60_000L);
  }

  @Test
  @DisplayName("팩토리는 네트워크 없이 baseUrl 유무와 상관없이 클라이언트를 만든다")
  void factory_createsClient() {
    AiRestClientFactory factory = new AiRestClientFactory(new AiHttpProperties(null, null));

    assertThat(factory.create("https://example.com")).isNotNull();
    assertThat(factory.create(null)).isNotNull();
  }
}
