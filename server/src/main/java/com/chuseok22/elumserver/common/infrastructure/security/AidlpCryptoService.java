package com.chuseok22.elumserver.common.infrastructure.security;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.AidlpProperties;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.Base64;
import javax.crypto.Cipher;
import javax.crypto.Mac;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

// AI DLP 요청 암호화의 순수 crypto 로직. HKDF-SHA256으로 마스터 시크릿에서 요청별 키를 파생하고,
// AES-256-GCM 복호화와 HMAC-SHA256 서명 검증을 담당한다. 클라이언트와 규약(info 라벨·바이트 순서)을 맞춘다.
@Service
@RequiredArgsConstructor
public class AidlpCryptoService {

  private static final int GCM_TAG_BITS = 128;
  private static final Base64.Decoder B64_DEC = Base64.getDecoder();

  private final AidlpProperties properties;

  // 봉투를 AES-256-GCM으로 복호화해 평문 바이트를 돌려준다. 태그 불일치·형식 오류는 DLP_DECRYPT_FAILED.
  public byte[] decrypt(AidlpEnvelope env) {
    try {
      byte[] salt = B64_DEC.decode(env.salt());
      byte[] iv = B64_DEC.decode(env.iv());
      byte[] ct = B64_DEC.decode(env.ciphertext()); // 암호문+태그
      byte[] aesKey = deriveKey(salt, "elum-aes-gcm");

      Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
      cipher.init(Cipher.DECRYPT_MODE, new SecretKeySpec(aesKey, "AES"), new GCMParameterSpec(GCM_TAG_BITS, iv));
      return cipher.doFinal(ct);
    } catch (Exception e) {
      // 원문·키를 로그에 남기지 않는다. 실패 사실만 던진다.
      throw new CustomException(ErrorCode.DLP_DECRYPT_FAILED);
    }
  }

  // timestamp.nonce.ciphertext를 HMAC-SHA256으로 서명한 값과 상수시간 비교한다.
  public boolean verifySignature(String timestamp, String nonceB64, String ciphertextB64,
    String saltB64, String signatureB64) {
    try {
      byte[] salt = B64_DEC.decode(saltB64);
      byte[] hmacKey = deriveKey(salt, "elum-hmac-sha256");
      String signing = timestamp + "." + nonceB64 + "." + ciphertextB64;
      byte[] expected = hmac(hmacKey, signing.getBytes(StandardCharsets.UTF_8));
      byte[] actual = B64_DEC.decode(signatureB64);
      return MessageDigest.isEqual(expected, actual); // 상수시간 비교
    } catch (Exception e) {
      return false;
    }
  }

  // HKDF-SHA256(RFC 5869). Extract(salt, ikm) → Expand(prk, info, 32B). 단일 블록(L<=32)만 필요하다.
  byte[] deriveKey(byte[] salt, String info) {
    try {
      byte[] ikm = properties.getSecret().getBytes(StandardCharsets.UTF_8);
      byte[] prk = hmac(salt, ikm); // Extract
      // Expand: T(1) = HMAC(prk, info || 0x01)
      byte[] infoBytes = info.getBytes(StandardCharsets.UTF_8);
      byte[] input = Arrays.copyOf(infoBytes, infoBytes.length + 1);
      input[infoBytes.length] = 0x01;
      byte[] t1 = hmac(prk, input);
      return Arrays.copyOf(t1, 32); // AES-256 / HMAC-SHA256 키 모두 32B
    } catch (Exception e) {
      throw new CustomException(ErrorCode.DLP_DECRYPT_FAILED);
    }
  }

  private byte[] hmac(byte[] key, byte[] data) throws Exception {
    Mac mac = Mac.getInstance("HmacSHA256");
    mac.init(new SecretKeySpec(key, "HmacSHA256"));
    return mac.doFinal(data);
  }
}
