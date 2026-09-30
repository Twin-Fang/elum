package com.chuseok22.elumserver.adreward.application.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.security.KeyFactory;
import java.security.PublicKey;
import java.security.spec.X509EncodedKeySpec;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.function.Supplier;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/**
 * Google 의 보상 검증 공개키 목록을 받아 캐시한다 (#463).
 *
 * <ul>
 *   <li>**캐시한다(24시간).** 콜백마다 받으면 Google 장애가 곧 보상 장애가 된다.</li>
 *   <li>**모르는 `key_id` 가 오면 한 번 다시 받는다.** Google 이 키를 바꿨다면 옛 캐시로는 정상 콜백을 모두 거절한다.</li>
 *   <li>**그 재조회는 5분에 한 번으로 제한한다.** 가짜 `key_id` 를 마구 보내 Google 을 두드리게 두지 않는다.</li>
 *   <li>**받지 못하면 만료된 캐시라도 쓴다.** 캐시마저 없으면 "확인할 수 없음"으로 알려 지급하지 않는다(5xx).</li>
 * </ul>
 */
@Slf4j
@Component
public class GoogleSsvKeyProvider implements SsvKeyProvider {

  static final String KEYS_URL = "https://www.gstatic.com/admob/reward/verifier-keys.json";
  private static final Duration CACHE_TTL = Duration.ofHours(24);
  private static final Duration MISS_REFRESH_INTERVAL = Duration.ofMinutes(5);
  /// 캐시가 없거나 만료돼 받으러 갔다가 실패한 뒤 다시 시도하기까지의 간격. 그 사이 요청은 네트워크를 타지 않는다.
  private static final Duration FAILURE_RETRY_INTERVAL = Duration.ofSeconds(30);

  /// JSON 파싱 전용. 빈으로 등록하지 않는다(JwkKeyResolver 와 같은 이유 — 앱에 ObjectMapper 빈이 없다).
  private static final ObjectMapper MAPPER = new ObjectMapper();

  private final Supplier<String> fetcher;
  private final Clock clock;

  private Map<String, PublicKey> keys = Map.of();
  private Instant fetchedAt;
  /// 캐시가 없거나 만료돼서 받으려 한 마지막 시각(실패 포함).
  private Instant lastAttemptAt;
  /// 모르는 key_id 때문에 다시 받은 마지막 시각.
  private Instant lastMissRefreshAt;

  @Autowired
  // RestClient 빈이 여럿이라 이름으로 고른다(타임아웃이 설정된 외부 호출용 클라이언트).
  public GoogleSsvKeyProvider(@Qualifier("oauthRestClient") RestClient oauthRestClient) {
    this(() -> oauthRestClient.get().uri(KEYS_URL).retrieve().body(String.class), Clock.systemUTC());
  }

  GoogleSsvKeyProvider(Supplier<String> fetcher, Clock clock) {
    this.fetcher = fetcher;
    this.clock = clock;
  }

  /**
   * 한 번에 한 요청만 받으러 간다(여러 콜백이 동시에 몰려도 Google 을 한 번만 부른다). 받으러 가는 횟수는 **캐시 상태와
   * 무관하게 간격으로 제한**한다 — 인증 없는 콜백에 가짜 `key_id` 를 몰아 보내도 스레드가 네트워크 대기에 줄줄이 묶이지 않는다.
   */
  @Override
  public synchronized Optional<PublicKey> find(String keyId) {
    Instant now = clock.instant();
    boolean fresh = fetchedAt != null && now.isBefore(fetchedAt.plus(CACHE_TTL));

    if (fresh) {
      PublicKey cached = keys.get(keyId);
      if (cached != null) {
        return Optional.of(cached);
      }
      // 캐시는 살아 있는데 이 키가 없다 = 키가 바뀌었거나 가짜 id 다. 다시 받는 것은 5분에 한 번만 한다.
      if (lastMissRefreshAt != null && now.isBefore(lastMissRefreshAt.plus(MISS_REFRESH_INTERVAL))) {
        // 방금 다시 받았는데 또 모르는 키다. 키 회전 직후의 정상 콜백일 수도 있어 "틀렸다"가 아니라 "확인할 수 없다"로
        // 알려 Google 이 다시 보내게 한다.
        throw new SsvKeysUnavailableException("모르는 key_id 로 방금 키를 다시 받았다. 잠시 뒤 다시 확인한다");
      }
      lastMissRefreshAt = now;
      refresh(now);
      return Optional.ofNullable(keys.get(keyId));
    }

    // 캐시가 없거나 만료됐다. 최근에 시도했다면 다시 받으러 가지 않는다.
    if (lastAttemptAt != null && now.isBefore(lastAttemptAt.plus(FAILURE_RETRY_INTERVAL))) {
      PublicKey stale = keys.get(keyId);
      if (stale != null) {
        return Optional.of(stale);
      }
      throw new SsvKeysUnavailableException("최근에 공개키를 받지 못했다. 잠시 뒤 다시 시도한다");
    }
    lastAttemptAt = now;
    refresh(now);
    return Optional.ofNullable(keys.get(keyId));
  }

  private void refresh(Instant now) {
    try {
      Map<String, PublicKey> fetched = parse(fetcher.get());
      keys = fetched;
      fetchedAt = now;
    } catch (RuntimeException e) {
      if (!keys.isEmpty()) {
        // 만료됐거나 새 키를 못 받았어도 아는 키로는 검증할 수 있다. 완전히 멈추는 것보다 낫다.
        log.warn("Google SSV 공개키를 새로 받지 못해 가진 캐시로 검증한다: {}", e.toString());
        return;
      }
      log.error("Google SSV 공개키를 받지 못했고 캐시도 없다", e);
      throw new SsvKeysUnavailableException("Google 공개키를 받지 못했다", e);
    }
  }

  private static Map<String, PublicKey> parse(String body) {
    if (body == null || body.isBlank()) {
      throw new IllegalStateException("응답이 비었다");
    }
    try {
      JsonNode list = MAPPER.readTree(body).path("keys");
      Map<String, PublicKey> result = new HashMap<>();
      KeyFactory factory = KeyFactory.getInstance("EC");
      for (JsonNode node : list) {
        String keyId = node.path("keyId").asText(null);
        String der = node.path("base64").asText(null);
        if (keyId == null || der == null) {
          continue;
        }
        try {
          result.put(keyId, factory.generatePublic(new X509EncodedKeySpec(Base64.getDecoder().decode(der))));
        } catch (Exception e) {
          // 키 하나가 깨졌다고 나머지까지 못 쓰게 하지 않는다.
          log.warn("Google SSV 공개키 하나를 읽지 못했다: keyId={}", keyId);
        }
      }
      if (result.isEmpty()) {
        throw new IllegalStateException("쓸 수 있는 키가 하나도 없다");
      }
      return Map.copyOf(result);
    } catch (RuntimeException e) {
      throw e;
    } catch (Exception e) {
      throw new IllegalStateException("키 목록을 읽지 못했다", e);
    }
  }
}
