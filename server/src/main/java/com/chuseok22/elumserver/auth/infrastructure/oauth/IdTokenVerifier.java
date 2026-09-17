package com.chuseok22.elumserver.auth.infrastructure.oauth;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import java.nio.charset.StandardCharsets;
import java.security.PublicKey;
import java.util.Base64;
import java.util.Collection;
import java.util.List;
import java.util.Set;
import lombok.extern.slf4j.Slf4j;

/**
 * ID 토큰(JWT)을 공개키로 검증하는 방식의 공통 뼈대. 구글·애플이 여기에 해당한다.
 *
 * <p>카카오·네이버처럼 제공자 API를 호출하지 않는다. 서명만 맞으면 내용이 참이므로
 * 네트워크 왕복이 한 번 줄고, 제공자 API 장애에도 로그인이 살아 있다.
 *
 * <p><b>서명 검증만으로는 부족하다.</b> 구글이 서명한 토큰은 전 세계 모든 구글 앱의
 * 토큰이다. {@code aud}가 우리 앱인지 확인하지 않으면 아무 앱에서나 받은 토큰으로
 * 우리 계정에 로그인할 수 있다. 그래서 이 클래스는 aud 목록이 비어 있으면
 * 검증을 통과시키지 않고 실패시킨다.
 */
@Slf4j
public abstract class IdTokenVerifier implements OAuthVerifier {

  private final JwkKeyResolver jwkKeyResolver;

  protected IdTokenVerifier(JwkKeyResolver jwkKeyResolver) {
    this.jwkKeyResolver = jwkKeyResolver;
  }

  protected abstract String jwksUrl();

  protected abstract Set<String> allowedIssuers();

  protected abstract List<String> allowedAudiences();

  @Override
  public OAuthUser verify(String idToken) {
    List<String> audiences = allowedAudiences();
    if (audiences.isEmpty()) {
      // 설정 누락을 "검증 생략"으로 흘려보내지 않는다. 열린 문으로 두느니 로그인을 막는다.
      log.error("{} 클라이언트 ID가 설정되지 않아 ID 토큰을 검증할 수 없습니다", provider());
      throw new CustomException(ErrorCode.OAUTH_VERIFICATION_FAILED);
    }

    Claims claims = parseAndVerifySignature(idToken);

    if (!allowedIssuers().contains(claims.getIssuer())) {
      log.warn("{} ID 토큰의 발급자가 일치하지 않습니다. iss={}", provider(), claims.getIssuer());
      throw new CustomException(ErrorCode.OAUTH_VERIFICATION_FAILED);
    }

    if (audienceOf(claims).stream().noneMatch(audiences::contains)) {
      log.warn("{} ID 토큰이 우리 앱을 위해 발급된 것이 아닙니다", provider());
      throw new CustomException(ErrorCode.OAUTH_VERIFICATION_FAILED);
    }

    String subject = claims.getSubject();
    if (subject == null || subject.isBlank()) {
      throw new CustomException(ErrorCode.OAUTH_VERIFICATION_FAILED);
    }

    return new OAuthUser(subject, claims.get("email", String.class), emailVerifiedOf(claims));
  }

  private Claims parseAndVerifySignature(String idToken) {
    PublicKey publicKey = jwkKeyResolver.resolve(jwksUrl(), keyIdOf(idToken));
    try {
      // 만료(exp)·형식 검증은 파서가 함께 수행한다. 공개키로 검증하므로
      // alg를 none이나 HMAC으로 바꿔치기한 토큰은 여기서 걸러진다.
      return Jwts.parser()
        .verifyWith(publicKey)
        .build()
        .parseSignedClaims(idToken)
        .getPayload();
    } catch (Exception e) {
      log.warn("{} ID 토큰 검증에 실패했습니다", provider(), e);
      throw new CustomException(ErrorCode.OAUTH_VERIFICATION_FAILED);
    }
  }

  /** 서명을 검증하기 전이라 헤더만 따로 읽는다. 여기서 얻는 값은 kid뿐이다. */
  private String keyIdOf(String idToken) {
    try {
      String[] parts = idToken.split("\\.");
      if (parts.length != 3) {
        throw new CustomException(ErrorCode.OAUTH_VERIFICATION_FAILED);
      }
      String headerJson = new String(Base64.getUrlDecoder().decode(parts[0]), StandardCharsets.UTF_8);
      // 헤더는 작고 구조가 고정이라 Jackson을 끌어오지 않고 직접 찾는다.
      return extractJsonString(headerJson, "kid");
    } catch (CustomException e) {
      throw e;
    } catch (Exception e) {
      throw new CustomException(ErrorCode.OAUTH_VERIFICATION_FAILED);
    }
  }

  private String extractJsonString(String json, String field) {
    String marker = "\"" + field + "\"";
    int keyIndex = json.indexOf(marker);
    if (keyIndex < 0) {
      throw new CustomException(ErrorCode.OAUTH_VERIFICATION_FAILED);
    }
    int start = json.indexOf('"', json.indexOf(':', keyIndex + marker.length()) + 1);
    int end = json.indexOf('"', start + 1);
    if (start < 0 || end < 0) {
      throw new CustomException(ErrorCode.OAUTH_VERIFICATION_FAILED);
    }
    return json.substring(start + 1, end);
  }

  /** aud는 문자열 하나로도, 배열로도 온다. 둘 다 받아 준다. */
  private Collection<String> audienceOf(Claims claims) {
    Object aud = claims.get("aud");
    if (aud instanceof String single) {
      return List.of(single);
    }
    if (aud instanceof Collection<?> many) {
      return many.stream().map(String::valueOf).toList();
    }
    return List.of();
  }

  /** 애플은 email_verified를 boolean이 아니라 "true" 문자열로 보내는 경우가 있다. */
  private boolean emailVerifiedOf(Claims claims) {
    Object verified = claims.get("email_verified");
    if (verified instanceof Boolean bool) {
      return bool;
    }
    return "true".equalsIgnoreCase(String.valueOf(verified));
  }
}
