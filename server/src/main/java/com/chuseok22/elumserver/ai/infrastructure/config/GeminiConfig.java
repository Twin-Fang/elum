package com.chuseok22.elumserver.ai.infrastructure.config;

import com.chuseok22.elumserver.common.infrastructure.properties.GeminiProperties;
import java.net.http.HttpClient;
import java.time.Duration;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

@Configuration
@RequiredArgsConstructor
public class GeminiConfig {

  private final GeminiProperties geminiProperties;

  @Bean
  public RestClient geminiRestClient() {
    Duration timeout = Duration.ofMillis(geminiProperties.timeoutMillis());
    HttpClient httpClient = HttpClient.newBuilder()
      .connectTimeout(timeout)
      .build();

    JdkClientHttpRequestFactory requestFactory = new JdkClientHttpRequestFactory(httpClient);
    requestFactory.setReadTimeout(timeout);

    return RestClient.builder()
      .baseUrl(geminiProperties.baseUrl())
      .requestFactory(requestFactory)
      .build();
  }
}
