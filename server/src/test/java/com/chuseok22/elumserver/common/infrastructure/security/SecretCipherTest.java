package com.chuseok22.elumserver.common.infrastructure.security;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.infrastructure.properties.SecretProperties;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class SecretCipherTest {

  private static final String API_KEY = "sk-proj-abcdefghijklmnopqrstuvwxyz0123456789";

  private SecretCipher cipher(String masterKey) {
    return new SecretCipher(new SecretProperties(masterKey));
  }

  @Test
  @DisplayName("넣은 값이 그대로 돌아온다")
  void roundTrip() {
    SecretCipher cipher = cipher("master-key");

    String encrypted = cipher.encrypt(API_KEY);

    assertThat(encrypted).isNotNull().isNotEqualTo(API_KEY);
    assertThat(cipher.decrypt(encrypted)).isEqualTo(API_KEY);
  }

  @Test
  @DisplayName("같은 값을 두 번 넣어도 암호문이 다르다 — 초기화 벡터를 매번 새로 뽑기 때문")
  void sameInput_differentCiphertext() {
    SecretCipher cipher = cipher("master-key");

    assertThat(cipher.encrypt(API_KEY)).isNotEqualTo(cipher.encrypt(API_KEY));
  }

  @Test
  @DisplayName("한글과 긴 값도 그대로 돌아온다")
  void handlesUnicodeAndLongValues() {
    SecretCipher cipher = cipher("master-key");
    String value = "키-한글-".repeat(30);

    assertThat(cipher.decrypt(cipher.encrypt(value))).isEqualTo(value);
  }

  @Test
  @DisplayName("마스터 키가 없으면 암·복호화를 하지 않는다. 서버는 그대로 뜬다")
  void noMasterKey_disabled() {
    SecretCipher cipher = cipher(null);

    assertThat(cipher.isAvailable()).isFalse();
    assertThat(cipher.encrypt(API_KEY)).isNull();
    assertThat(cipher.decrypt("아무값")).isNull();

    assertThat(cipher("  ").isAvailable()).isFalse();
  }

  @Test
  @DisplayName("다른 마스터 키로는 풀리지 않는다")
  void differentMasterKey_cannotDecrypt() {
    String encrypted = cipher("master-key").encrypt(API_KEY);

    assertThat(cipher("다른-키").decrypt(encrypted)).isNull();
  }

  @Test
  @DisplayName("값이 손상되면 조용히 통과하지 않고 실패한다 — 변조를 잡는다")
  void tamperedCiphertext_fails() {
    SecretCipher cipher = cipher("master-key");
    String encrypted = cipher.encrypt(API_KEY);

    // 마지막 글자를 바꿔 태그를 깨뜨린다
    char last = encrypted.charAt(encrypted.length() - 1);
    String tampered = encrypted.substring(0, encrypted.length() - 1) + (last == 'A' ? 'B' : 'A');

    assertThat(cipher.decrypt(tampered)).isNull();
  }

  @Test
  @DisplayName("빈 값·짧은 쓰레기 값에도 죽지 않는다")
  void malformedInput_returnsNull() {
    SecretCipher cipher = cipher("master-key");

    assertThat(cipher.decrypt(null)).isNull();
    assertThat(cipher.decrypt("")).isNull();
    assertThat(cipher.decrypt("   ")).isNull();
    assertThat(cipher.decrypt("not-base64!!")).isNull();
    assertThat(cipher.decrypt("QUJD")).isNull();
    assertThat(cipher.encrypt(null)).isNull();
  }
}
