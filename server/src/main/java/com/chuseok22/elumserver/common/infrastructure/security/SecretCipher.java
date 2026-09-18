package com.chuseok22.elumserver.common.infrastructure.security;

import com.chuseok22.elumserver.common.infrastructure.properties.SecretProperties;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 시스템 설정에 담는 비밀값을 AES-GCM으로 감싼다.
 *
 * <p>GCM을 쓰는 이유는 <b>변조를 잡아내기 위해서</b>다. 단순 암호화만 하면 누가 DB의
 * 암호문을 바꿔치기해도 복호화가 조용히 성공해 엉뚱한 값이 흘러간다. GCM은 태그가
 * 맞지 않으면 복호화 자체가 실패한다.
 *
 * <p>초기화 벡터(IV)는 매번 새로 뽑아 암호문 앞에 붙인다. 같은 키를 두 번 저장해도
 * 암호문이 달라야 하고, GCM에서 같은 키·같은 IV를 재사용하면 보호가 깨진다.
 *
 * <p>마스터 키가 없으면 {@link #isAvailable()}이 false가 되고 암·복호화를 시도하지
 * 않는다. 서버는 그대로 기동하며, 비밀값을 쓰는 기능만 "설정 없음"으로 남는다.
 */
@Slf4j
@Component
public class SecretCipher {

  private static final String TRANSFORMATION = "AES/GCM/NoPadding";
  private static final int IV_LENGTH = 12;
  private static final int TAG_BITS = 128;

  private final SecretKeySpec key;
  private final SecureRandom random = new SecureRandom();

  public SecretCipher(SecretProperties secretProperties) {
    this.key = secretProperties.hasMasterKey()
      ? deriveKey(secretProperties.masterKey())
      : null;
    if (this.key == null) {
      log.warn("비밀값 마스터 키가 없습니다. 외부 API 키를 화면에서 저장할 수 없습니다.");
    }
  }

  public boolean isAvailable() {
    return key != null;
  }

  /// 평문 → Base64(IV + 암호문 + 태그). 마스터 키가 없으면 null.
  public String encrypt(String plain) {
    if (key == null || plain == null) {
      return null;
    }
    try {
      byte[] iv = new byte[IV_LENGTH];
      random.nextBytes(iv);
      Cipher cipher = Cipher.getInstance(TRANSFORMATION);
      cipher.init(Cipher.ENCRYPT_MODE, key, new GCMParameterSpec(TAG_BITS, iv));
      byte[] encrypted = cipher.doFinal(plain.getBytes(StandardCharsets.UTF_8));

      byte[] combined = new byte[iv.length + encrypted.length];
      System.arraycopy(iv, 0, combined, 0, iv.length);
      System.arraycopy(encrypted, 0, combined, iv.length, encrypted.length);
      return Base64.getEncoder().encodeToString(combined);
    } catch (Exception e) {
      // 암호화 실패의 원인에는 평문이 섞일 수 있으므로 예외 메시지를 로그에 남기지 않는다.
      log.error("비밀값 암호화에 실패했습니다: {}", e.getClass().getSimpleName());
      return null;
    }
  }

  /// Base64 암호문 → 평문. 풀 수 없으면 null (마스터 키가 바뀌었거나 값이 손상된 경우).
  public String decrypt(String encoded) {
    if (key == null || encoded == null || encoded.isBlank()) {
      return null;
    }
    try {
      byte[] combined = Base64.getDecoder().decode(encoded);
      if (combined.length <= IV_LENGTH) {
        return null;
      }
      byte[] iv = new byte[IV_LENGTH];
      System.arraycopy(combined, 0, iv, 0, IV_LENGTH);
      byte[] encrypted = new byte[combined.length - IV_LENGTH];
      System.arraycopy(combined, IV_LENGTH, encrypted, 0, encrypted.length);

      Cipher cipher = Cipher.getInstance(TRANSFORMATION);
      cipher.init(Cipher.DECRYPT_MODE, key, new GCMParameterSpec(TAG_BITS, iv));
      return new String(cipher.doFinal(encrypted), StandardCharsets.UTF_8);
    } catch (Exception e) {
      log.warn("비밀값 복호화에 실패했습니다. 마스터 키가 바뀌었거나 값이 손상됐습니다: {}",
        e.getClass().getSimpleName());
      return null;
    }
  }

  // 사용자가 넣는 마스터 키는 길이가 제각각이라 그대로 AES 키로 쓸 수 없다.
  // SHA-256으로 항상 32바이트를 만든다.
  private static SecretKeySpec deriveKey(String masterKey) {
    try {
      MessageDigest digest = MessageDigest.getInstance("SHA-256");
      return new SecretKeySpec(digest.digest(masterKey.getBytes(StandardCharsets.UTF_8)), "AES");
    } catch (Exception e) {
      throw new IllegalStateException("마스터 키를 만들 수 없습니다", e);
    }
  }
}
