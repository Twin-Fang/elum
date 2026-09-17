package com.chuseok22.elumserver.auth.infrastructure.oauth;

import com.chuseok22.elumserver.common.infrastructure.properties.OAuthProperties;
import java.net.http.HttpClient;
import java.time.Duration;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

@Configuration
@RequiredArgsConstructor
public class OAuthHttpConfig {

  private final OAuthProperties oAuthProperties;

  /**
   * 제공자 API·JWKS 조회에 함께 쓰는 클라이언트. baseUrl을 두지 않아 각 검증기가
   * 자기 엔드포인트를 절대 URL로 지정한다.
   */
  @Bean
  public RestClient oauthRestClient() {
    Duration timeout = Duration.ofMillis(oAuthProperties.timeoutMillis());
    HttpClient httpClient = HttpClient.newBuilder()
      .connectTimeout(timeout)
      .build();

    JdkClientHttpRequestFactory requestFactory = new JdkClientHttpRequestFactory(httpClient);
    requestFactory.setReadTimeout(timeout);

    return RestClient.builder()
      .requestFactory(requestFactory)
      .build();
  }
}
