package com.chuseok22.elumserver.license.infrastructure.store.apple;

import com.chuseok22.elumserver.common.infrastructure.json.DefaultJsonMapper;
import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.Signature;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.security.spec.PKCS8EncodedKeySpec;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * App Store JWS 시험 재료: 시험용 자체 서명 체인(trusted·attacker)으로 x5c + ES256 서명
 * 인증서·키는 src/test/resources/store/apple (openssl 로 만든 시험 전용, Apple OID 확장 포함). 실제 Apple 호출 없음
 */
public final class AppleJwsTestFixtures {

  public static final String BUNDLE_ID = "kr.twinfang.elum";
  public static final long APP_APPLE_ID = 6792970508L;
  public static final String PRODUCT_ID = "elum_pro_monthly";
  public static final String TRUSTED = "trusted";
  public static final String ATTACKER = "attacker";

  private static final String RESOURCE_DIRECTORY = "/store/apple/";
  private static final Base64.Encoder BASE64_URL = Base64.getUrlEncoder().withoutPadding();

  private AppleJwsTestFixtures() {
  }

  /// 시험 검증기가 믿는 루트 (trusted 체인의 루트만)
  public static List<byte[]> trustedRoots() {
    return List.of(certificate(TRUSTED, "root").getEncodedSafely());
  }

  /// 체인 이름(trusted·attacker)의 leaf 키로 payload 를 서명한 JWS
  public static String sign(String chain, Map<String, Object> payload) {
    try {
      Map<String, Object> header = new LinkedHashMap<>();
      header.put("alg", "ES256");
      header.put("x5c", List.of(
        base64(certificate(chain, "leaf")), base64(certificate(chain, "int")), base64(certificate(chain, "root"))));
      String signingInput = BASE64_URL.encodeToString(DefaultJsonMapper.SHARED.writeValueAsBytes(header))
        + "." + BASE64_URL.encodeToString(DefaultJsonMapper.SHARED.writeValueAsBytes(payload));
      Signature signature = Signature.getInstance("SHA256withECDSAinP1363Format");
      signature.initSign(leafKey(chain));
      signature.update(signingInput.getBytes(StandardCharsets.US_ASCII));
      return signingInput + "." + BASE64_URL.encodeToString(signature.sign());
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }

  /// 서명은 그대로 두고 payload 만 바꾼 JWS (변조)
  public static String replacePayload(String jws, Map<String, Object> newPayload) {
    try {
      String[] parts = jws.split("\\.");
      return parts[0] + "." + BASE64_URL.encodeToString(DefaultJsonMapper.SHARED.writeValueAsBytes(newPayload)) + "." + parts[2];
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }

  /// 자동 갱신 구독 거래 payload (Apple JSON 필드명)
  public static Map<String, Object> transaction(
    String originalTransactionId, String transactionId, String environment, long expiresDateMillis, String appAccountToken
  ) {
    Map<String, Object> payload = new LinkedHashMap<>();
    payload.put("transactionId", transactionId);
    payload.put("originalTransactionId", originalTransactionId);
    payload.put("bundleId", BUNDLE_ID);
    payload.put("productId", PRODUCT_ID);
    payload.put("purchaseDate", System.currentTimeMillis() - 60_000);
    payload.put("expiresDate", expiresDateMillis);
    payload.put("type", "Auto-Renewable Subscription");
    payload.put("inAppOwnershipType", "PURCHASED");
    payload.put("environment", environment);
    payload.put("signedDate", System.currentTimeMillis());
    if (appAccountToken != null) {
      payload.put("appAccountToken", appAccountToken);
    }
    return payload;
  }

  public static Map<String, Object> notification(String notificationType, String subtype, String uuid, String environment,
    Long appAppleId, String signedTransactionInfo, String signedRenewalInfo) {
    Map<String, Object> data = new LinkedHashMap<>();
    // appAppleId null: Sandbox 알림처럼 앱 ID 없이 옴 (#1187)
    if (appAppleId != null) {
      data.put("appAppleId", appAppleId);
    }
    data.put("bundleId", BUNDLE_ID);
    data.put("environment", environment);
    data.put("signedTransactionInfo", signedTransactionInfo);
    if (signedRenewalInfo != null) {
      data.put("signedRenewalInfo", signedRenewalInfo);
    }
    Map<String, Object> payload = new LinkedHashMap<>();
    payload.put("notificationType", notificationType);
    if (subtype != null) {
      payload.put("subtype", subtype);
    }
    payload.put("notificationUUID", uuid);
    payload.put("data", data);
    payload.put("version", "2.0");
    payload.put("signedDate", System.currentTimeMillis());
    return payload;
  }

  private static String base64(CertificateHolder holder) {
    return Base64.getEncoder().encodeToString(holder.getEncodedSafely());
  }

  private static CertificateHolder certificate(String chain, String role) {
    try (InputStream input = resource(chain + "-" + role + ".pem")) {
      X509Certificate certificate = (X509Certificate) CertificateFactory.getInstance("X.509").generateCertificate(input);
      return new CertificateHolder(certificate);
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }

  private static PrivateKey leafKey(String chain) throws Exception {
    try (InputStream input = resource(chain + "-leaf.pk8.pem")) {
      String pem = new String(input.readAllBytes(), StandardCharsets.US_ASCII)
        .replace("-----BEGIN PRIVATE KEY-----", "").replace("-----END PRIVATE KEY-----", "").replaceAll("\\s+", "");
      return KeyFactory.getInstance("EC").generatePrivate(new PKCS8EncodedKeySpec(Base64.getDecoder().decode(pem)));
    }
  }

  private static InputStream resource(String name) {
    InputStream input = AppleJwsTestFixtures.class.getResourceAsStream(RESOURCE_DIRECTORY + name);
    if (input == null) {
      throw new UncheckedIOException(new IOException("missing fixture " + name));
    }
    return input;
  }

  private record CertificateHolder(X509Certificate certificate) {

    byte[] getEncodedSafely() {
      try {
        return certificate.getEncoded();
      } catch (Exception e) {
        throw new IllegalStateException(e);
      }
    }
  }
}
