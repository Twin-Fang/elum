package com.chuseok22.elumserver.auth.infrastructure.oauth;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.OAuthProperties;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/**
 * 카카오 액세스 토큰 검증.
 *
 * <p>두 번 호출한다. 한 번으로 줄이고 싶지만 그럴 수 없다.
 * <ul>
 *   <li>{@code /v1/user/access_token_info} — 이 토큰이 <b>우리 앱</b> 것인지 확인한다(app_id).
 *       이 확인이 구글·애플의 aud 검증에 해당한다.</li>
 *   <li>{@code /v2/user/me} — 이메일을 가져온다. 카카오에서 이메일은 선택 동의라
 *       아예 없을 수 있고, 있어도 미인증일 수 있다.</li>
 * </ul>
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class KakaoOAuthVerifier implements OAuthVerifier {

  private static final String TOKEN_INFO_URL = "https://kapi.kakao.com/v1/user/access_token_info";
  private static final String USER_ME_URL = "https://kapi.kakao.com/v2/user/me";

  private final RestClient oauthRestClient;
  private final ObjectMapper objectMapper;
  private final OAuthProperties oAuthProperties;

  @Override
  public OAuthProvider provider() {
    return OAuthProvider.KAKAO;
  }

  @Override
  public OAuthUser verify(String accessToken) {
    String configuredAppId = oAuthProperties.kakao().appId();
    if (configuredAppId == null || configuredAppId.isBlank()) {
      // 앱 ID를 모르면 남의 앱 토큰을 걸러낼 수 없다. 통과시키지 않는다.
      log.error("카카오 앱 ID가 설정되지 않아 토큰을 검증할 수 없습니다");
      throw new CustomException(ErrorCode.OAUTH_VERIFICATION_FAILED);
    }

    JsonNode tokenInfo = get(TOKEN_INFO_URL, accessToken);
    String appId = tokenInfo.path("app_id").asText(null);
    if (!configuredAppId.equals(appId)) {
      log.warn("카카오 토큰이 우리 앱을 위해 발급된 것이 아닙니다. appId={}", appId);
      throw new CustomException(ErrorCode.OAUTH_VERIFICATION_FAILED);
    }

    String providerUserId = tokenInfo.path("id").asText(null);
    if (providerUserId == null || providerUserId.isBlank()) {
      throw new CustomException(ErrorCode.OAUTH_VERIFICATION_FAILED);
    }

    JsonNode account = get(USER_ME_URL, accessToken).path("kakao_account");
    String email = account.path("email").asText(null);
    // 카카오는 인증 여부를 is_email_verified로 따로 알려준다. 동의만 받고 미인증인 주소가 있다.
    boolean emailVerified = account.path("is_email_verified").asBoolean(false);

    return new OAuthUser(providerUserId, email, emailVerified);
  }

  private JsonNode get(String url, String accessToken) {
    try {
      String body = oauthRestClient.get()
        .uri(url)
        .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
        .retrieve()
        .body(String.class);
      return objectMapper.readTree(body);
    } catch (Exception e) {
      // 만료·위조·카카오 장애를 구분해 알리지 않는다. 공격자에게 힌트가 된다.
      log.warn("카카오 API 호출에 실패했습니다. url={}", url, e);
      throw new CustomException(ErrorCode.OAUTH_VERIFICATION_FAILED);
    }
  }
}
