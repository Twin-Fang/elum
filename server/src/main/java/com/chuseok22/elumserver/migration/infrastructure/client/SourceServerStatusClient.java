package com.chuseok22.elumserver.migration.infrastructure.client;

import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.net.http.HttpClient;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/**
 * 옛 서버 공개 상태 조회 (#1062): GET {옛 서버}/api/app/status, 연결·응답 각 3초, 인증 없음
 * 상태 코드와 상관없이 응답을 그대로 돌려줌. 연결 실패·시간 초과는 RestClientException (ResourceAccessException)
 */
@Component
public class SourceServerStatusClient {

  static final String APP_STATUS_PATH = "/api/app/status";
  // 관리자 화면을 오래 붙잡지 않게 짧게 (초)
  private static final Duration CONNECT_TIMEOUT = Duration.ofSeconds(3);
  private static final Duration READ_TIMEOUT = Duration.ofSeconds(3);
  // 응답 본문 최대 크기 (64KB, 상태 JSON 은 1KB 안팎)
  private static final int MAX_BODY_BYTES = 65_536;

  private final RestClient restClient;

  public SourceServerStatusClient() {
    // 다른 곳으로 넘기는 응답은 따라가지 않음 (HttpClient 기본 NEVER)
    HttpClient httpClient = HttpClient.newBuilder().connectTimeout(CONNECT_TIMEOUT).build();
    JdkClientHttpRequestFactory requestFactory = new JdkClientHttpRequestFactory(httpClient);
    requestFactory.setReadTimeout(READ_TIMEOUT);
    this.restClient = RestClient.builder().requestFactory(requestFactory).build();
  }

  /// 옛 서버 기준 주소 > 상태 코드 + 본문 (본문은 앞 64KB 까지)
  public SourceServerHttpResponse fetchAppStatus(String sourceBaseUrl) {
    return restClient.get()
      .uri(URI.create(sourceBaseUrl + APP_STATUS_PATH))
      .exchange((request, response) -> new SourceServerHttpResponse(
        response.getStatusCode().value(), readLimitedBody(response.getBody())));
  }

  private static String readLimitedBody(InputStream body) throws IOException {
    if (body == null) {
      return "";
    }
    return new String(body.readNBytes(MAX_BODY_BYTES), StandardCharsets.UTF_8);
  }

  /// 옛 서버 응답: 상태 코드, 본문 글
  public record SourceServerHttpResponse(int statusCode, String body) {
  }
}
