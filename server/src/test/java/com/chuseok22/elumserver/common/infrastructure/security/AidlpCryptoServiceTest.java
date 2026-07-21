package com.chuseok22.elumserver.common.infrastructure.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.properties.AidlpProperties;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Base64;
import javax.crypto.Cipher;
import javax.crypto.Mac;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class AidlpCryptoServiceTest {

  private AidlpCryptoService service;
  private final SecureRandom random = new SecureRandom();

  @BeforeEach
  void setUp() {
    AidlpProperties props = new AidlpProperties();
    props.setSecret("test-master-secret-32bytes-minimum!!"); // 테스트 전용 값
    service = new AidlpCryptoService(props);
  }

  // 클라이언트가 만들 봉투를 서버가 복호화할 수 있는지를, 서버가 동일 규약으로 만든 봉투로 검증한다.
  @Test
  void aesGcm_왕복_복호화() throws Exception {
    byte[] salt = randomBytes(16);
    byte[] iv = randomBytes(12);
    byte[] plain = "홍길동 010-1234-5678".getBytes(StandardCharsets.UTF_8);

    byte[] aesKey = service.deriveKey(salt, "elum-aes-gcm");
    Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
    cipher.init(Cipher.ENCRYPT_MODE, new SecretKeySpec(aesKey, "AES"), new GCMParameterSpec(128, iv));
    byte[] ct = cipher.doFinal(plain); // 암호문+태그

    AidlpEnvelope env = new AidlpEnvelope(b64(ct), b64(iv), b64(salt));
    byte[] decrypted = service.decrypt(env);

    assertThat(new String(decrypted, StandardCharsets.UTF_8)).isEqualTo("홍길동 010-1234-5678");
  }

  @Test
  void 잘못된_태그면_복호화_실패() {
    byte[] salt = randomBytes(16);
    byte[] iv = randomBytes(12);
    AidlpEnvelope env = new AidlpEnvelope(b64("corrupted".getBytes()), b64(iv), b64(salt));

    assertThatThrownBy(() -> service.decrypt(env))
      .isInstanceOf(CustomException.class);
  }

  @Test
  void HMAC_서명_검증_성공과_실패() {
    byte[] salt = randomBytes(16);
    String ts = "1700000000000";
    String nonce = b64(randomBytes(16));
    String ctB64 = b64(randomBytes(40));

    byte[] hmacKey = service.deriveKey(salt, "elum-hmac-sha256");
    String signing = ts + "." + nonce + "." + ctB64;
    String sig = b64(hmacSha256(hmacKey, signing.getBytes(StandardCharsets.UTF_8)));

    assertThat(service.verifySignature(ts, nonce, ctB64, b64(salt), sig)).isTrue();
    assertThat(service.verifySignature(ts, nonce, ctB64, b64(salt), b64("wrong".getBytes()))).isFalse();
  }

  private byte[] randomBytes(int n) {
    byte[] b = new byte[n];
    random.nextBytes(b);
    return b;
  }

  private static String b64(byte[] b) {
    return Base64.getEncoder().encodeToString(b);
  }

  private static byte[] hmacSha256(byte[] key, byte[] data) {
    try {
      Mac mac = Mac.getInstance("HmacSHA256");
      mac.init(new SecretKeySpec(key, "HmacSHA256"));
      return mac.doFinal(data);
    } catch (Exception e) {
      throw new RuntimeException(e);
    }
  }
}
