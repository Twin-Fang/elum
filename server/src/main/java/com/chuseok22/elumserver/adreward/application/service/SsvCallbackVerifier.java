package com.chuseok22.elumserver.adreward.application.service;

import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.security.PublicKey;
import java.security.Signature;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * Google 보상형 광고 서버 콜백(SSV)의 서명을 검증한다.
 *
 * <p>규칙은 Google 문서 그대로다.
 * <ul>
 *   <li>`signature` 와 `key_id` 는 **항상 마지막 두 파라미터**다.</li>
 *   <li>서명 대상은 `&signature=` 앞까지의 **원문 쿼리 문자열**이다. 디코딩하거나 다시 만들지 않는다 —
 *       퍼센트 인코딩이 한 글자만 달라져도 검증이 깨진다.</li>
 *   <li>서명은 URL-safe Base64 의 DER ECDSA, 알고리즘은 SHA256withECDSA 다.</li>
 * </ul>
 *
 * <p>이 검증이 뚫리면 누구나 시청을 꾸며 크레딧을 받는다. 그래서 **의심스러우면 모두 거절**한다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class SsvCallbackVerifier {

  private static final String SIGNATURE_MARKER = "&signature=";
  private static final String KEY_ID_MARKER = "&key_id=";

  private final SsvKeyProvider keyProvider;

  /**
   * @param rawQuery 서블릿이 준 **디코딩 전** 쿼리 문자열
   * @throws SsvInvalidException         서명이 없거나 틀렸거나 형식이 맞지 않을 때
   * @throws SsvKeysUnavailableException 공개키를 받지 못해 확인할 수 없을 때
   */
  public SsvCallback verify(String rawQuery) {
    if (rawQuery == null || rawQuery.isBlank()) {
      throw new SsvInvalidException("쿼리가 비었다");
    }
    int signatureAt = rawQuery.lastIndexOf(SIGNATURE_MARKER);
    if (signatureAt < 0) {
      throw new SsvInvalidException("서명이 없다");
    }
    int keyIdAt = rawQuery.indexOf(KEY_ID_MARKER, signatureAt);
    if (keyIdAt < 0) {
      throw new SsvInvalidException("key_id 가 없다");
    }

    String signedMessage = rawQuery.substring(0, signatureAt);
    String encodedSignature = rawQuery.substring(signatureAt + SIGNATURE_MARKER.length(), keyIdAt);
    String keyId = rawQuery.substring(keyIdAt + KEY_ID_MARKER.length());
    if (encodedSignature.isEmpty() || keyId.isEmpty() || keyId.contains("&")) {
      throw new SsvInvalidException("서명 자리의 형식이 맞지 않다");
    }

    byte[] signatureBytes = decodeSignature(encodedSignature);
    PublicKey publicKey = keyProvider.find(keyId)
      .orElseThrow(() -> new SsvInvalidException("모르는 key_id 다"));
    if (!signatureMatches(signedMessage, signatureBytes, publicKey)) {
      throw new SsvInvalidException("서명이 맞지 않다");
    }

    Map<String, String> params = parse(signedMessage);
    String customData = params.get("custom_data");
    String transactionId = params.get("transaction_id");
    if (isBlank(customData) || isBlank(transactionId)) {
      // 서명은 맞아도 누구의 시청인지·한 번의 시청인지 알 수 없으면 쓸 수 없다.
      throw new SsvInvalidException("custom_data 나 transaction_id 가 없다");
    }
    return new SsvCallback(
      normalizeAdUnit(params.get("ad_unit")), customData, transactionId, params.get("user_id"));
  }

  private static byte[] decodeSignature(String encoded) {
    try {
      // Google 은 패딩 없는 URL-safe Base64 를 준다. 디코더는 패딩이 있어도 받는다.
      return Base64.getUrlDecoder().decode(encoded);
    } catch (IllegalArgumentException e) {
      throw new SsvInvalidException("서명이 Base64 가 아니다");
    }
  }

  private static boolean signatureMatches(String message, byte[] signatureBytes, PublicKey key) {
    try {
      Signature signature = Signature.getInstance("SHA256withECDSA");
      signature.initVerify(key);
      signature.update(message.getBytes(StandardCharsets.UTF_8));
      return signature.verify(signatureBytes);
    } catch (Exception e) {
      // DER 형식이 아니거나 키 종류가 맞지 않는 경우도 "틀린 서명"이다.
      return false;
    }
  }

  private static Map<String, String> parse(String query) {
    Map<String, String> params = new HashMap<>();
    for (String pair : query.split("&")) {
      int eq = pair.indexOf('=');
      if (eq <= 0) {
        continue;
      }
      String name = pair.substring(0, eq);
      String value = URLDecoder.decode(pair.substring(eq + 1), StandardCharsets.UTF_8);
      // 같은 이름이 두 번 오면 첫 값을 쓴다 — 뒤에 덧붙여 값을 바꾸는 시도를 막는다.
      params.putIfAbsent(name, value);
    }
    return params;
  }

  /// `ca-app-pub-…/123` 처럼 오면 뒤의 숫자만 남긴다.
  static String normalizeAdUnit(String adUnit) {
    if (adUnit == null) {
      return "";
    }
    String trimmed = adUnit.trim();
    int slash = trimmed.lastIndexOf('/');
    return slash >= 0 ? trimmed.substring(slash + 1) : trimmed;
  }

  private static boolean isBlank(String value) {
    return value == null || value.isBlank();
  }
}
