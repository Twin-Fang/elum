package com.chuseok22.elumserver.auth.infrastructure.oauth;

import com.chuseok22.elumserver.common.infrastructure.properties.OAuthProperties;
import java.util.List;
import java.util.Set;
import org.springframework.stereotype.Component;

/**
 * 구글 ID 토큰 검증.
 *
 * <p>안드로이드·iOS·웹이 각각 다른 클라이언트 ID를 쓰므로 aud 허용 목록에 전부 넣는다.
 * 하나만 넣어 두면 다른 플랫폼에서 로그인이 실패한다.
 */
@Component
public class GoogleOAuthVerifier extends IdTokenVerifier {

  private static final String JWKS_URL = "https://www.googleapis.com/oauth2/v3/certs";
  // 구글은 두 형태의 iss를 모두 발급한다. 하나만 허용하면 일부 기기에서 로그인이 막힌다.
  private static final Set<String> ISSUERS = Set.of("accounts.google.com", "https://accounts.google.com");

  private final OAuthProperties oAuthProperties;

  public GoogleOAuthVerifier(JwkKeyResolver jwkKeyResolver, OAuthProperties oAuthProperties) {
    super(jwkKeyResolver);
    this.oAuthProperties = oAuthProperties;
  }

  @Override
  public OAuthProvider provider() {
    return OAuthProvider.GOOGLE;
  }

  @Override
  protected String jwksUrl() {
    return JWKS_URL;
  }

  @Override
  protected Set<String> allowedIssuers() {
    return ISSUERS;
  }

  @Override
  protected List<String> allowedAudiences() {
    return oAuthProperties.google().clientIds();
  }
}
