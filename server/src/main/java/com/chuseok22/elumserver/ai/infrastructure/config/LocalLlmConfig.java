package com.chuseok22.elumserver.ai.infrastructure.config;

import com.chuseok22.elumserver.common.infrastructure.properties.LocalLlmProperties;
import java.net.http.HttpClient;
import java.time.Duration;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

@Configuration
@RequiredArgsConstructor
public class LocalLlmConfig {

  private final LocalLlmProperties localLlmProperties;

  @Bean
  public RestClient localLlmRestClient() {
    Duration timeout = Duration.ofMillis(localLlmProperties.timeoutMillis());
    HttpClient httpClient = HttpClient.newBuilder()
      .connectTimeout(timeout)
      .build();

    JdkClientHttpRequestFactory requestFactory = new JdkClientHttpRequestFactory(httpClient);
    requestFactory.setReadTimeout(timeout);

    return RestClient.builder()
      .baseUrl(localLlmProperties.baseUrl())
      .requestFactory(requestFactory)
      .build();
  }
}
