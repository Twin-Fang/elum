package com.chuseok22.elumserver.auth.infrastructure.oauth;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.math.BigInteger;
import java.security.KeyFactory;
import java.security.PublicKey;
import java.security.spec.RSAPublicKeySpec;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/**
 * 구글·애플의 공개키(JWKS)를 가져와 kid로 찾아 준다.
 *
 * <p>제공자는 키를 주기적으로 갈아 끼운다. 그래서 캐시에 없는 kid가 오면 한 번은
 * 다시 받아 본다. 반대로 매 로그인마다 받아 오면 제공자 장애가 곧 우리 로그인 장애가
 * 되므로 짧게 캐시한다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class JwkKeyResolver {

  private static final Duration CACHE_TTL = Duration.ofHours(1);

  /// JSON 파싱 전용. **빈으로 등록하지 않는다** — 이 앱에는 ObjectMapper 빈이 없고,
  /// 새로 등록하면 Spring MVC의 JSON 처리 설정까지 바뀐다. ObjectMapper는 thread-safe라
  /// 정적 인스턴스로 공유해도 안전하다.
  private static final ObjectMapper MAPPER = new ObjectMapper();

  private final RestClient oauthRestClient;

  private final Map<String, CachedKeys> cache = new ConcurrentHashMap<>();

  public PublicKey resolve(String jwksUrl, String kid) {
    if (kid == null || kid.isBlank()) {
      throw new CustomException(ErrorCode.OAUTH_VERIFICATION_FAILED);
    }

    CachedKeys cached = cache.get(jwksUrl);
    if (cached != null && !cached.isExpired()) {
      PublicKey key = cached.keys().get(kid);
      if (key != null) {
        return key;
      }
      // 캐시는 살아 있는데 kid가 없다 = 키가 교체됐다. 아래에서 다시 받는다.
    }

    CachedKeys fetched = new CachedKeys(fetchKeys(jwksUrl), Instant.now().plus(CACHE_TTL));
    cache.put(jwksUrl, fetched);

    PublicKey key = fetched.keys().get(kid);
    if (key == null) {
      log.warn("JWKS에 없는 kid입니다. url={}, kid={}", jwksUrl, kid);
      throw new CustomException(ErrorCode.OAUTH_VERIFICATION_FAILED);
    }
    return key;
  }

  private Map<String, PublicKey> fetchKeys(String jwksUrl) {
    String body;
    try {
      body = oauthRestClient.get()
        .uri(jwksUrl)
        .retrieve()
        .body(String.class);
    } catch (Exception e) {
      log.warn("JWKS 조회에 실패했습니다. url={}", jwksUrl, e);
      throw new CustomException(ErrorCode.OAUTH_VERIFICATION_FAILED);
    }

    try {
      JsonNode keys = MAPPER.readTree(body).path("keys");
      Map<String, PublicKey> result = new HashMap<>();
      KeyFactory keyFactory = KeyFactory.getInstance("RSA");

      for (JsonNode jwk : keys) {
        // RSA 외 타입(EC 등)이 섞여 올 수 있다. 우리가 쓰는 것만 담는다.
        if (!"RSA".equals(jwk.path("kty").asText())) {
          continue;
        }
        String keyId = jwk.path("kid").asText(null);
        String modulus = jwk.path("n").asText(null);
        String exponent = jwk.path("e").asText(null);
        if (keyId == null || modulus == null || exponent == null) {
          continue;
        }

        Base64.Decoder decoder = Base64.getUrlDecoder();
        // JWK의 n·e는 부호 없는 빅엔디안이므로 signum을 1로 고정한다.
        // (생략하면 최상위 비트가 1인 키가 음수로 해석돼 검증이 조용히 실패한다)
        BigInteger n = new BigInteger(1, decoder.decode(modulus));
        BigInteger e = new BigInteger(1, decoder.decode(exponent));
        result.put(keyId, keyFactory.generatePublic(new RSAPublicKeySpec(n, e)));
      }

      if (result.isEmpty()) {
        throw new CustomException(ErrorCode.OAUTH_VERIFICATION_FAILED);
      }
      return Map.copyOf(result);
    } catch (CustomException e) {
      throw e;
    } catch (Exception e) {
      log.warn("JWKS 파싱에 실패했습니다. url={}", jwksUrl, e);
      throw new CustomException(ErrorCode.OAUTH_VERIFICATION_FAILED);
    }
  }

  private record CachedKeys(Map<String, PublicKey> keys, Instant expiresAt) {

    boolean isExpired() {
      return Instant.now().isAfter(expiresAt);
    }
  }
}
