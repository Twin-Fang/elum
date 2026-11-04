package com.chuseok22.elumserver.license.infrastructure.store.apple;

import static com.chuseok22.elumserver.license.infrastructure.store.apple.AppleJwsTestFixtures.APP_APPLE_ID;
import static com.chuseok22.elumserver.license.infrastructure.store.apple.AppleJwsTestFixtures.ATTACKER;
import static com.chuseok22.elumserver.license.infrastructure.store.apple.AppleJwsTestFixtures.BUNDLE_ID;
import static com.chuseok22.elumserver.license.infrastructure.store.apple.AppleJwsTestFixtures.TRUSTED;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.apple.itunes.storekit.model.JWSTransactionDecodedPayload;
import com.apple.itunes.storekit.model.NotificationTypeV2;
import com.apple.itunes.storekit.model.ResponseBodyV2DecodedPayload;
import com.chuseok22.elumserver.license.application.service.store.StoreVerifyRejectedException;
import com.chuseok22.elumserver.license.core.StoreEnvironment;
import com.chuseok22.elumserver.license.core.StoreVerifyRejectReason;
import com.chuseok22.elumserver.license.infrastructure.store.apple.AppleSignedDataVerifier.AppleVerifyContext;
import com.chuseok22.elumserver.license.infrastructure.store.apple.AppleSignedDataVerifier.Verified;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * App Store 서명 검증: 위조·변조·다른 앱·테스트 결제가 Pro 로 이어지지 않는가 (시험용 자체 서명 루트를 믿는 검증기)
 */
class AppleSignedDataVerifierTest {

  private static final AppleVerifyContext PRODUCTION_ONLY = new AppleVerifyContext(BUNDLE_ID, APP_APPLE_ID, false);
  private static final AppleVerifyContext SANDBOX_ALLOWED = new AppleVerifyContext(BUNDLE_ID, APP_APPLE_ID, true);
  private static final long ONE_DAY_MILLIS = 86_400_000L;

  private final AppleSignedDataVerifier verifier = new AppleSignedDataVerifier(AppleJwsTestFixtures.trustedRoots());

  @Test
  @DisplayName("믿는 루트로 서명된 Production 거래는 통과하고 값이 그대로 풀린다")
  void validProductionTransaction_isDecoded() {
    String jws = AppleJwsTestFixtures.sign(TRUSTED, transaction("Production"));

    Verified<JWSTransactionDecodedPayload> verified = verifier.verifyTransaction(jws, PRODUCTION_ONLY);

    assertThat(verified.environment()).isEqualTo(StoreEnvironment.PRODUCTION);
    assertThat(verified.payload().getOriginalTransactionId()).isEqualTo("1000000000000001");
    assertThat(verified.payload().getProductId()).isEqualTo(AppleJwsTestFixtures.PRODUCT_ID);
  }

  @Test
  @DisplayName("서명 뒤 payload 를 바꾸면(만료일 늘리기) 거부된다 — 변조 영수증으로 Pro 를 늘리지 못한다")
  void tamperedPayload_isRejected() {
    String jws = AppleJwsTestFixtures.sign(TRUSTED, transaction("Production"));
    Map<String, Object> extended = transaction("Production");
    extended.put("expiresDate", System.currentTimeMillis() + 3650 * ONE_DAY_MILLIS);

    assertRejected(() -> verifier.verifyTransaction(AppleJwsTestFixtures.replacePayload(jws, extended), PRODUCTION_ONLY),
      StoreVerifyRejectReason.SIGNATURE_INVALID);
  }

  @Test
  @DisplayName("직접 만든 인증서 체인으로 서명한 거래는 거부된다 — 위조 영수증")
  void untrustedChain_isRejected() {
    String forged = AppleJwsTestFixtures.sign(ATTACKER, transaction("Production"));

    assertRejected(() -> verifier.verifyTransaction(forged, PRODUCTION_ONLY), StoreVerifyRejectReason.SIGNATURE_INVALID);
  }

  @Test
  @DisplayName("다른 앱(번들 ID)의 진짜 거래는 거부된다 — 남의 앱 구독으로 Pro 를 받지 못한다")
  void otherBundleId_isRejected() {
    Map<String, Object> payload = transaction("Production");
    payload.put("bundleId", "com.example.other");

    assertRejected(() -> verifier.verifyTransaction(AppleJwsTestFixtures.sign(TRUSTED, payload), PRODUCTION_ONLY),
      StoreVerifyRejectReason.APP_MISMATCH);
  }

  @Test
  @DisplayName("Sandbox 거래는 테스트 결제 허용이 꺼져 있으면 거부, 켜져 있으면 SANDBOX 로 통과한다")
  void sandboxTransaction_dependsOnSetting() {
    String jws = AppleJwsTestFixtures.sign(TRUSTED, transaction("Sandbox"));

    assertRejected(() -> verifier.verifyTransaction(jws, PRODUCTION_ONLY), StoreVerifyRejectReason.ENVIRONMENT_NOT_ALLOWED);
    assertThat(verifier.verifyTransaction(jws, SANDBOX_ALLOWED).environment()).isEqualTo(StoreEnvironment.SANDBOX);
  }

  @Test
  @DisplayName("Xcode 로컬 서명 환경 거래는 Sandbox 허용이어도 거부된다 — 서명 검증을 건너뛰는 환경")
  void xcodeEnvironment_isRejected() {
    String jws = AppleJwsTestFixtures.sign(TRUSTED, transaction("Xcode"));

    assertRejected(() -> verifier.verifyTransaction(jws, SANDBOX_ALLOWED), StoreVerifyRejectReason.ENVIRONMENT_NOT_ALLOWED);
  }

  @Test
  @DisplayName("결제 알림: 앱 ID 가 맞으면 통과, 다른 앱 ID 면 거부된다")
  void notification_checksAppAppleId() {
    String transaction = AppleJwsTestFixtures.sign(TRUSTED, transaction("Production"));
    String valid = AppleJwsTestFixtures.sign(TRUSTED, AppleJwsTestFixtures.notification(
      "DID_RENEW", null, "uuid-1", "Production", APP_APPLE_ID, transaction, null));
    String otherApp = AppleJwsTestFixtures.sign(TRUSTED, AppleJwsTestFixtures.notification(
      "DID_RENEW", null, "uuid-2", "Production", 1L, transaction, null));

    Verified<ResponseBodyV2DecodedPayload> verified = verifier.verifyNotification(valid, PRODUCTION_ONLY);

    assertThat(verified.payload().getNotificationType()).isEqualTo(NotificationTypeV2.DID_RENEW);
    assertRejected(() -> verifier.verifyNotification(otherApp, PRODUCTION_ONLY), StoreVerifyRejectReason.APP_MISMATCH);
  }

  @Test
  @DisplayName("JWS 형식이 아닌 값은 형식 오류로 거부된다 (서버 오류가 아니다)")
  void garbage_isRejected() {
    assertThatThrownBy(() -> verifier.verifyTransaction("not-a-jws", PRODUCTION_ONLY))
      .isInstanceOf(StoreVerifyRejectedException.class);
  }

  private static Map<String, Object> transaction(String environment) {
    return AppleJwsTestFixtures.transaction("1000000000000001", "2000000000000001", environment,
      System.currentTimeMillis() + 30 * ONE_DAY_MILLIS, null);
  }

  private static void assertRejected(Runnable call, StoreVerifyRejectReason reason) {
    assertThatThrownBy(call::run)
      .isInstanceOfSatisfying(StoreVerifyRejectedException.class, e -> assertThat(e.getReason()).isEqualTo(reason));
  }
}
