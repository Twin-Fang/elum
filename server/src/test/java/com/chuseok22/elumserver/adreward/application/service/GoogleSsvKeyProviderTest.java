package com.chuseok22.elumserver.adreward.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Base64;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Google 공개키 목록을 받아 캐시하는 방식 (#463).
 *
 * <p>Google 장애가 곧 보상 장애가 되면 안 되고, 반대로 Google 이 키를 바꿨는데 우리가 옛 캐시만 보면 정상 콜백이
 * 모두 거절된다. 그래서 (1) 캐시하고 (2) 모르는 키가 오면 한 번은 다시 받되 (3) 그 재조회는 제한한다.
 */
class GoogleSsvKeyProviderTest {

  private KeyPair pairA;
  private KeyPair pairB;
  private MutableClock clock;
  private final AtomicInteger fetchCount = new AtomicInteger();
  private String body;
  private boolean fetchFails;
  private GoogleSsvKeyProvider provider;

  @BeforeEach
  void setUp() throws Exception {
    pairA = newKeyPair();
    pairB = newKeyPair();
    clock = new MutableClock(Instant.parse("2026-09-30T00:00:00Z"));
    body = keysJson(entry("111", pairA));
    provider = new GoogleSsvKeyProvider(() -> {
      fetchCount.incrementAndGet();
      if (fetchFails) {
        throw new IllegalStateException("네트워크 오류");
      }
      return body;
    }, clock);
  }

  @Test
  void 처음_조회하면_받아서_찾는다() {
    assertThat(provider.find("111")).contains(pairA.getPublic());
    assertThat(fetchCount).hasValue(1);
  }

  @Test
  void 캐시된_키는_다시_받지_않는다() {
    provider.find("111");
    provider.find("111");
    provider.find("111");

    assertThat(fetchCount).hasValue(1);
  }

  @Test
  void 캐시가_만료되면_다시_받는다() {
    provider.find("111");
    clock.advance(Duration.ofHours(25));
    provider.find("111");

    assertThat(fetchCount).hasValue(2);
  }

  @Test
  void 모르는_키가_오면_한_번_다시_받아_새_키를_찾는다() throws Exception {
    provider.find("111");
    body = keysJson(entry("111", pairA), entry("222", pairB));
    clock.advance(Duration.ofMinutes(6));

    assertThat(provider.find("222")).contains(pairB.getPublic());
    assertThat(fetchCount).hasValue(2);
  }

  @Test
  void 방금_다시_받았는데도_없는_키는_확실히_모르는_키다() {
    provider.find("111");
    clock.advance(Duration.ofMinutes(6));

    // 모르는 키가 와서 한 번 다시 받아 봤고, 그래도 없다 — 빈 값(서명 거절 400)이 맞다.
    assertThat(provider.find("999")).isEmpty();
    assertThat(fetchCount).hasValue(2);
  }

  @Test
  void 모르는_키로_계속_와도_5분_안에는_다시_받지_않고_잠시_뒤_다시_시도하게_알린다() {
    provider.find("111");
    clock.advance(Duration.ofMinutes(6));
    provider.find("999");

    // 5분 안에 또 모르는 키가 오면 Google 을 다시 두드리지 않는다. 가짜 key_id 를 마구 보내도 호출은 늘지 않는다.
    // 진짜 키 회전 직후의 정상 콜백일 수도 있으니 "틀렸다(400)"가 아니라 "확인할 수 없다(503)"로 알려 Google 이 다시 보내게 한다.
    assertThatThrownBy(() -> provider.find("999")).isInstanceOf(SsvKeysUnavailableException.class);
    assertThatThrownBy(() -> provider.find("998")).isInstanceOf(SsvKeysUnavailableException.class);
    assertThat(fetchCount).hasValue(2);
  }

  @Test
  void 재시도_간격이_지나면_모르는_키도_다시_받아_본다() throws Exception {
    provider.find("111");
    clock.advance(Duration.ofMinutes(6));
    provider.find("999");
    body = keysJson(entry("111", pairA), entry("222", pairB));
    clock.advance(Duration.ofMinutes(6));

    assertThat(provider.find("222")).contains(pairB.getPublic());
    assertThat(fetchCount).hasValue(3);
  }

  @Test
  void 받지_못했고_캐시도_없으면_확인할_수_없다고_알린다() {
    fetchFails = true;

    assertThatThrownBy(() -> provider.find("111")).isInstanceOf(SsvKeysUnavailableException.class);
  }

  @Test
  void 받지_못했어도_만료된_캐시가_있으면_그걸로_찾는다() {
    provider.find("111");
    clock.advance(Duration.ofHours(30));
    fetchFails = true;

    assertThat(provider.find("111")).contains(pairA.getPublic());
  }

  @Test
  void 받지_못하는_동안_요청이_몰려도_Google을_계속_두드리지_않는다() {
    fetchFails = true;

    for (int i = 0; i < 20; i++) {
      assertThatThrownBy(() -> provider.find("111")).isInstanceOf(SsvKeysUnavailableException.class);
    }
    // 첫 시도 한 번뿐이다. 나머지 19번은 네트워크를 타지 않고 곧바로 "확인할 수 없음"으로 답한다.
    assertThat(fetchCount).hasValue(1);
  }

  @Test
  void 받지_못하던_상태는_간격이_지나면_다시_시도해_회복한다() {
    fetchFails = true;
    assertThatThrownBy(() -> provider.find("111")).isInstanceOf(SsvKeysUnavailableException.class);

    fetchFails = false;
    clock.advance(Duration.ofSeconds(31));

    assertThat(provider.find("111")).contains(pairA.getPublic());
    assertThat(fetchCount).hasValue(2);
  }

  @Test
  void 캐시가_만료된_뒤_받기가_실패해도_요청마다_다시_시도하지_않는다() {
    provider.find("111");
    clock.advance(Duration.ofHours(30));
    fetchFails = true;

    for (int i = 0; i < 10; i++) {
      assertThat(provider.find("111")).contains(pairA.getPublic());
    }
    // 처음 1번 + 만료 뒤 첫 시도 1번. 그 뒤 9번은 가진 캐시로만 답한다.
    assertThat(fetchCount).hasValue(2);
  }

  @Test
  void 응답이_JSON이_아니면_확인할_수_없다고_알린다() {
    body = "<html>오류</html>";

    assertThatThrownBy(() -> provider.find("111")).isInstanceOf(SsvKeysUnavailableException.class);
  }

  @Test
  void 키가_하나도_없는_응답도_확인할_수_없다고_알린다() {
    body = "{\"keys\":[]}";

    assertThatThrownBy(() -> provider.find("111")).isInstanceOf(SsvKeysUnavailableException.class);
  }

  @Test
  void 키_하나가_깨져도_나머지는_쓴다() throws Exception {
    body = "{\"keys\":[{\"keyId\":333,\"base64\":\"깨진값\"},"
      + entry("111", pairA) + "]}";

    assertThat(provider.find("111")).contains(pairA.getPublic());
  }

  // ---------------------------------------------------------------------------------------------

  private static KeyPair newKeyPair() throws Exception {
    KeyPairGenerator generator = KeyPairGenerator.getInstance("EC");
    generator.initialize(256);
    return generator.generateKeyPair();
  }

  private static String entry(String keyId, KeyPair pair) {
    String der = Base64.getEncoder().encodeToString(pair.getPublic().getEncoded());
    return "{\"keyId\":" + keyId + ",\"pem\":\"-----BEGIN PUBLIC KEY-----\\n" + der
      + "\\n-----END PUBLIC KEY-----\",\"base64\":\"" + der + "\"}";
  }

  private static String keysJson(String... entries) {
    return "{\"keys\":[" + String.join(",", entries) + "]}";
  }

  private static final class MutableClock extends Clock {

    private Instant now;

    MutableClock(Instant start) {
      this.now = start;
    }

    void advance(Duration duration) {
      now = now.plus(duration);
    }

    @Override
    public java.time.ZoneId getZone() {
      return ZoneOffset.UTC;
    }

    @Override
    public Clock withZone(java.time.ZoneId zone) {
      return this;
    }

    @Override
    public Instant instant() {
      return now;
    }
  }
}
