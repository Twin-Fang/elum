package com.chuseok22.elumserver.adreward.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.PublicKey;
import java.security.Signature;
import java.security.spec.ECGenParameterSpec;
import java.util.Base64;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Google 보상형 광고 콜백(SSV)의 서명 검증 (#463).
 *
 * <p>이 검증이 뚫리면 누구나 "광고를 봤다"고 꾸며 크레딧을 받는다. 그래서 정상 한 가지보다
 * **틀린 것을 하나씩 바꿔 모두 막히는지**를 본다.
 */
class SsvCallbackVerifierTest {

  private static final String KEY_ID = "3335741209";
  private static final String BASE_QUERY =
    "ad_network=5450213213286189855&ad_unit=6517734434&custom_data=nonce-abc&reward_amount=1"
      + "&reward_item=Reward&timestamp=1791000000000&transaction_id=TX-1&user_id=member-1";

  private KeyPair keyPair;
  private KeyPair otherKeyPair;
  private FakeKeys keys;
  private SsvCallbackVerifier verifier;

  @BeforeEach
  void setUp() throws Exception {
    keyPair = newKeyPair();
    otherKeyPair = newKeyPair();
    keys = new FakeKeys();
    keys.put(KEY_ID, keyPair.getPublic());
    verifier = new SsvCallbackVerifier(keys);
  }

  @Test
  void 올바른_서명이면_콜백_값을_읽어_돌려준다() throws Exception {
    SsvCallback callback = verifier.verify(signed(BASE_QUERY, keyPair, KEY_ID));

    assertThat(callback.adUnit()).isEqualTo("6517734434");
    assertThat(callback.customData()).isEqualTo("nonce-abc");
    assertThat(callback.transactionId()).isEqualTo("TX-1");
    assertThat(callback.userId()).isEqualTo("member-1");
  }

  @Test
  void 쿼리를_한_글자라도_바꾸면_거절한다() throws Exception {
    String query = signed(BASE_QUERY, keyPair, KEY_ID);
    String tampered = query.replace("reward_amount=1", "reward_amount=9");

    assertThatThrownBy(() -> verifier.verify(tampered)).isInstanceOf(SsvInvalidException.class);
  }

  @Test
  void 다른_nonce로_바꿔도_거절한다() throws Exception {
    String query = signed(BASE_QUERY, keyPair, KEY_ID);
    String tampered = query.replace("custom_data=nonce-abc", "custom_data=nonce-xyz");

    assertThatThrownBy(() -> verifier.verify(tampered)).isInstanceOf(SsvInvalidException.class);
  }

  @Test
  void 다른_키로_서명한_것은_거절한다() throws Exception {
    String query = signed(BASE_QUERY, otherKeyPair, KEY_ID);

    assertThatThrownBy(() -> verifier.verify(query)).isInstanceOf(SsvInvalidException.class);
  }

  @Test
  void 서명이_없으면_거절한다() {
    assertThatThrownBy(() -> verifier.verify(BASE_QUERY + "&key_id=" + KEY_ID))
      .isInstanceOf(SsvInvalidException.class);
  }

  @Test
  void key_id가_없으면_거절한다() throws Exception {
    String query = signed(BASE_QUERY, keyPair, KEY_ID).replace("&key_id=" + KEY_ID, "");

    assertThatThrownBy(() -> verifier.verify(query)).isInstanceOf(SsvInvalidException.class);
  }

  @Test
  void 서명이_Base64가_아니면_거절한다() {
    assertThatThrownBy(() -> verifier.verify(BASE_QUERY + "&signature=***&key_id=" + KEY_ID))
      .isInstanceOf(SsvInvalidException.class);
  }

  @Test
  void 쿼리가_비었거나_null이면_거절한다() {
    assertThatThrownBy(() -> verifier.verify(null)).isInstanceOf(SsvInvalidException.class);
    assertThatThrownBy(() -> verifier.verify("")).isInstanceOf(SsvInvalidException.class);
  }

  @Test
  void 모르는_key_id면_거절한다() throws Exception {
    String query = signed(BASE_QUERY, keyPair, "999");

    assertThatThrownBy(() -> verifier.verify(query)).isInstanceOf(SsvInvalidException.class);
  }

  @Test
  void 공개키를_구하지_못하면_거절과_구분해_알린다() throws Exception {
    keys.unavailable = true;
    String query = signed(BASE_QUERY, keyPair, KEY_ID);

    // 키가 없어서 못 믿는 것과 서명이 틀린 것은 다르다 — 앞의 것은 Google 이 다시 보내게 5xx 로 답한다.
    assertThatThrownBy(() -> verifier.verify(query)).isInstanceOf(SsvKeysUnavailableException.class);
  }

  @Test
  void 값에_퍼센트_인코딩이_있어도_원문_그대로_서명을_검증하고_값은_풀어_읽는다() throws Exception {
    String query = "ad_unit=6517734434&custom_data=a%2Bb%3Dc&transaction_id=TX%2F2&timestamp=1";

    SsvCallback callback = verifier.verify(signed(query, keyPair, KEY_ID));

    assertThat(callback.customData()).isEqualTo("a+b=c");
    assertThat(callback.transactionId()).isEqualTo("TX/2");
  }

  @Test
  void 필수_값이_없으면_서명이_맞아도_거절한다() throws Exception {
    // 서명은 맞지만 custom_data·transaction_id 가 없다 — 누구의 시청인지 모른다.
    String query = signed("ad_unit=6517734434&timestamp=1", keyPair, KEY_ID);

    assertThatThrownBy(() -> verifier.verify(query)).isInstanceOf(SsvInvalidException.class);
  }

  // ---------------------------------------------------------------------------------------------

  private static KeyPair newKeyPair() throws Exception {
    KeyPairGenerator generator = KeyPairGenerator.getInstance("EC");
    generator.initialize(new ECGenParameterSpec("secp256r1"));
    return generator.generateKeyPair();
  }

  /// Google 이 하는 대로 만든다: 서명 대상은 `&signature=` 앞까지의 원문 쿼리, 서명은 URL-safe Base64(패딩 없음).
  private static String signed(String query, KeyPair pair, String keyId) throws Exception {
    Signature signature = Signature.getInstance("SHA256withECDSA");
    signature.initSign(pair.getPrivate());
    signature.update(query.getBytes(StandardCharsets.UTF_8));
    String encoded = Base64.getUrlEncoder().withoutPadding().encodeToString(signature.sign());
    return query + "&signature=" + encoded + "&key_id=" + keyId;
  }

  private static final class FakeKeys implements SsvKeyProvider {

    private final Map<String, PublicKey> keys = new java.util.HashMap<>();
    boolean unavailable;

    void put(String id, PublicKey key) {
      keys.put(id, key);
    }

    @Override
    public Optional<PublicKey> find(String keyId) {
      if (unavailable) {
        throw new SsvKeysUnavailableException("키를 받지 못했다");
      }
      return Optional.ofNullable(keys.get(keyId));
    }
  }
}
