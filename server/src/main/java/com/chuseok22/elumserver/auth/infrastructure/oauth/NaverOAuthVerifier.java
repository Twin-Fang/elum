package com.chuseok22.elumserver.auth.infrastructure.oauth;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/**
 * 네이버 액세스 토큰 검증.
 *
 * <p><b>알려진 한계</b> — 네이버는 카카오의 {@code app_id}나 구글의 {@code aud}처럼
 * "이 토큰이 어느 앱 것인지" 알려주는 값을 주지 않는다. 즉 다른 네이버 앱에서 받은
 * 액세스 토큰으로도 {@code /nid/me}는 정상 응답한다. 토큰 앞단에서 앱을 특정할 방법이
 * 프로토콜상 없다.
 *
 * <p>없애려면 클라이언트가 액세스 토큰 대신 <b>인가 코드</b>를 보내고 서버가
 * client_secret으로 교환하는 방식으로 바꿔야 한다. 그러면 우리 시크릿을 아는
 * 서버만 토큰을 얻을 수 있으므로 앱이 특정된다. 설정에 clientId/clientSecret을
 * 미리 받아 두는 이유가 이것이다. 지금은 모바일 SDK 흐름에 맞춰 액세스 토큰을 받고,
 * 이 한계를 기록으로 남긴다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class NaverOAuthVerifier implements OAuthVerifier {

  private static final String USER_ME_URL = "https://openapi.naver.com/v1/nid/me";

  /// JSON 파싱 전용. **빈으로 등록하지 않는다** — 이 앱에는 ObjectMapper 빈이 없고,
  /// 새로 등록하면 Spring MVC의 JSON 처리 설정까지 바뀐다. ObjectMapper는 thread-safe라
  /// 정적 인스턴스로 공유해도 안전하다.
  private static final ObjectMapper MAPPER = new ObjectMapper();

  private final RestClient oauthRestClient;

  @Override
  public OAuthProvider provider() {
    return OAuthProvider.NAVER;
  }

  @Override
  public OAuthUser verify(String accessToken) {
    JsonNode root;
    try {
      String body = oauthRestClient.get()
        .uri(USER_ME_URL)
        .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
        .retrieve()
        .body(String.class);
      root = MAPPER.readTree(body);
    } catch (Exception e) {
      log.warn("네이버 API 호출에 실패했습니다", e);
      throw new CustomException(ErrorCode.OAUTH_VERIFICATION_FAILED);
    }

    // 네이버는 HTTP 200으로 응답하면서 본문의 resultcode로 실패를 알린다.
    // 상태 코드만 보면 실패를 성공으로 읽는다.
    if (!"00".equals(root.path("resultcode").asText())) {
      log.warn("네이버가 토큰을 거부했습니다. resultcode={}", root.path("resultcode").asText());
      throw new CustomException(ErrorCode.OAUTH_VERIFICATION_FAILED);
    }

    JsonNode response = root.path("response");
    String providerUserId = response.path("id").asText(null);
    if (providerUserId == null || providerUserId.isBlank()) {
      throw new CustomException(ErrorCode.OAUTH_VERIFICATION_FAILED);
    }

    // 네이버는 이메일 인증 여부를 주지 않는다. 검증됐다고 단정할 수 없으므로 false로 둔다.
    return new OAuthUser(providerUserId, response.path("email").asText(null), false);
  }
}
