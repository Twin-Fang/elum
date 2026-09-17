package com.chuseok22.elumserver.auth.infrastructure.oauth;

import com.chuseok22.elumserver.common.infrastructure.properties.OAuthProperties;
import java.util.List;
import java.util.Set;
import org.springframework.stereotype.Component;

/**
 * 애플 ID 토큰 검증.
 *
 * <p>애플은 "내 이메일 숨기기"를 켜면 {@code @privaterelay.appleid.com} 주소를 준다.
 * 이 주소는 앱마다 다르므로 이메일로 사람을 식별하려 하면 안 된다. 계정 매칭은
 * 언제나 {@code sub}로 한다.
 *
 * <p>또 애플은 <b>최초 로그인 때만</b> 이름을 준다. 두 번째부터는 sub와 이메일만 온다.
 * 이름이 필요하면 첫 로그인에서 저장해야 한다.
 */
@Component
public class AppleOAuthVerifier extends IdTokenVerifier {

  private static final String JWKS_URL = "https://appleid.apple.com/auth/keys";
  private static final Set<String> ISSUERS = Set.of("https://appleid.apple.com");

  private final OAuthProperties oAuthProperties;

  public AppleOAuthVerifier(JwkKeyResolver jwkKeyResolver, OAuthProperties oAuthProperties) {
    super(jwkKeyResolver);
    this.oAuthProperties = oAuthProperties;
  }

  @Override
  public OAuthProvider provider() {
    return OAuthProvider.APPLE;
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
    return oAuthProperties.apple().bundleIds();
  }
}
