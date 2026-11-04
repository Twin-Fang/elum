package com.chuseok22.elumserver.adreward.infrastructure.client;

import java.net.URI;
import java.net.http.HttpClient;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/**
 * 광고 보상 콜백 전달: JDK HttpClient, 연결 5초·응답 10초 (Google 재시도 간격보다 짧게)
 */
@Component
public class RestAdSsvRelayClient implements AdSsvRelayClient {

  private static final Duration CONNECT_TIMEOUT = Duration.ofSeconds(5);
  private static final Duration READ_TIMEOUT = Duration.ofSeconds(10);
  private static final String RELAYED_HEADER_VALUE = "1";

  private final RestClient restClient;

  public RestAdSsvRelayClient() {
    HttpClient httpClient = HttpClient.newBuilder().connectTimeout(CONNECT_TIMEOUT).build();
    JdkClientHttpRequestFactory requestFactory = new JdkClientHttpRequestFactory(httpClient);
    requestFactory.setReadTimeout(READ_TIMEOUT);
    this.restClient = RestClient.builder().requestFactory(requestFactory).build();
  }

  @Override
  public RelayResponse forward(URI target) {
    // URI 를 그대로 넘긴다 (다시 인코딩하면 서명 검증 대상 쿼리가 달라진다)
    return restClient.get()
      .uri(target)
      .header(RELAYED_HEADER, RELAYED_HEADER_VALUE)
      .exchange((request, response) -> new RelayResponse(
        response.getStatusCode().value(),
        new String(response.getBody().readAllBytes(), StandardCharsets.UTF_8)
      ));
  }
}
