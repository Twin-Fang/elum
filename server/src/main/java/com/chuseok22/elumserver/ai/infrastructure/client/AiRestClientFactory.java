package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.common.infrastructure.properties.AiHttpProperties;
import java.time.Duration;
import lombok.RequiredArgsConstructor;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/// AI 제공자 클라이언트들이 같은 제한 시간 설정으로 RestClient를 만들도록 한 곳에 모은다.
@Component
@RequiredArgsConstructor
public class AiRestClientFactory {

  private final AiHttpProperties properties;

  /// baseUrl이 null이면 기준 주소 없이 만든다(외부 주소를 그대로 받아오는 용도).
  public RestClient create(String baseUrl) {
    SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
    factory.setConnectTimeout(Duration.ofMillis(properties.connectTimeoutMillis()));
    factory.setReadTimeout(Duration.ofMillis(properties.readTimeoutMillis()));
    RestClient.Builder builder = RestClient.builder().requestFactory(factory);
    return baseUrl == null ? builder.build() : builder.baseUrl(baseUrl).build();
  }
}
