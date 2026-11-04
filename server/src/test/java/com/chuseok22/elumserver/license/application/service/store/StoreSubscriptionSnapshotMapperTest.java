package com.chuseok22.elumserver.license.application.service.store;

import static org.assertj.core.api.Assertions.assertThat;

import com.apple.itunes.storekit.model.AutoRenewStatus;
import com.apple.itunes.storekit.model.JWSRenewalInfoDecodedPayload;
import com.apple.itunes.storekit.model.JWSTransactionDecodedPayload;
import com.apple.itunes.storekit.model.NotificationTypeV2;
import com.apple.itunes.storekit.model.Subtype;
import com.chuseok22.elumserver.common.infrastructure.json.DefaultJsonMapper;
import com.chuseok22.elumserver.license.core.StoreEnvironment;
import com.chuseok22.elumserver.license.core.StorePurchaseState;
import com.fasterxml.jackson.databind.JsonNode;
import java.time.LocalDateTime;
import java.time.ZoneId;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

/**
 * 결제 알림 > 구독 상태 매핑: 갱신·해지 예약·만료·환불·결제 유예가 Pro 여부로 맞게 바뀌는가 (App Store·Google Play)
 */
class StoreSubscriptionSnapshotMapperTest {

  private static final LocalDateTime NOW = LocalDateTime.of(2026, 11, 5, 12, 0);

  @ParameterizedTest(name = "{0}.{1} > {2}")
  @CsvSource(nullValues = "-", value = {
    "DID_RENEW, BILLING_RECOVERY, ACTIVE",
    "SUBSCRIBED, INITIAL_BUY, ACTIVE",
    "DID_CHANGE_RENEWAL_STATUS, AUTO_RENEW_DISABLED, ACTIVE",
    "DID_FAIL_TO_RENEW, GRACE_PERIOD, IN_GRACE_PERIOD",
    "DID_FAIL_TO_RENEW, -, BILLING_RETRY",
    "GRACE_PERIOD_EXPIRED, -, BILLING_RETRY",
    "EXPIRED, VOLUNTARY, EXPIRED",
    "REFUND, -, REVOKED",
    "REVOKE, -, REVOKED",
  })
  @DisplayName("App Store 알림 종류 > 구독 상태")
  void appleNotification_mapsToState(String type, String subtype, StorePurchaseState expected) {
    StoreSubscriptionSnapshot snapshot = AppleSubscriptionSnapshotMapper.toSnapshot(
      transaction(NOW.plusDays(20)), null, StoreEnvironment.PRODUCTION,
      NotificationTypeV2.valueOf(type), subtype == null ? null : Subtype.valueOf(subtype), null, NOW);

    assertThat(snapshot.state()).isEqualTo(expected);
    assertThat(snapshot.state().isEntitledState())
      .isEqualTo(expected == StorePurchaseState.ACTIVE || expected == StorePurchaseState.IN_GRACE_PERIOD);
  }

  @Test
  @DisplayName("App Store: 자동 갱신 꺼짐(해지 예약)은 만료일까지 Pro, willAutoRenew=false")
  void appleAutoRenewOff_keepsProUntilExpiry() {
    JWSRenewalInfoDecodedPayload renewal = new JWSRenewalInfoDecodedPayload();
    renewal.setOriginalTransactionId("1000000000000001");
    renewal.setAutoRenewStatus(AutoRenewStatus.OFF);

    StoreSubscriptionSnapshot snapshot = AppleSubscriptionSnapshotMapper.toSnapshot(
      transaction(NOW.plusDays(3)), renewal, StoreEnvironment.PRODUCTION, null, null, null, NOW);

    assertThat(snapshot.state()).isEqualTo(StorePurchaseState.ACTIVE);
    assertThat(snapshot.willAutoRenew()).isFalse();
  }

  @Test
  @DisplayName("App Store: 갱신 정보의 결제 재시도 + 유예 끝 시각이 있으면 유예, 그 시각까지 Pro")
  void appleBillingRetryWithGrace_isGracePeriod() {
    JWSRenewalInfoDecodedPayload renewal = new JWSRenewalInfoDecodedPayload();
    renewal.setIsInBillingRetryPeriod(true);
    renewal.setGracePeriodExpiresDate(millis(NOW.plusDays(6)));

    StoreSubscriptionSnapshot snapshot = AppleSubscriptionSnapshotMapper.toSnapshot(
      transaction(NOW.minusDays(1)), renewal, StoreEnvironment.PRODUCTION, null, null, null, NOW);

    assertThat(snapshot.state()).isEqualTo(StorePurchaseState.IN_GRACE_PERIOD);
    assertThat(snapshot.gracePeriodExpiresAt()).isEqualTo(NOW.plusDays(6));
  }

  @Test
  @DisplayName("App Store: 만료일이 지난 거래는 알림 없이도 만료")
  void appleExpiredByDate_isExpired() {
    StoreSubscriptionSnapshot snapshot = AppleSubscriptionSnapshotMapper.toSnapshot(
      transaction(NOW.minusMinutes(1)), null, StoreEnvironment.PRODUCTION, null, null, null, NOW);

    assertThat(snapshot.state()).isEqualTo(StorePurchaseState.EXPIRED);
  }

  @ParameterizedTest(name = "{0} > {1}")
  @CsvSource({
    "SUBSCRIPTION_STATE_ACTIVE, ACTIVE",
    "SUBSCRIPTION_STATE_CANCELED, ACTIVE",
    "SUBSCRIPTION_STATE_IN_GRACE_PERIOD, IN_GRACE_PERIOD",
    "SUBSCRIPTION_STATE_ON_HOLD, BILLING_RETRY",
    "SUBSCRIPTION_STATE_PAUSED, PAUSED",
    "SUBSCRIPTION_STATE_PENDING, PENDING",
    "SUBSCRIPTION_STATE_EXPIRED, EXPIRED",
    "SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED, EXPIRED",
    "SOMETHING_NEW, EXPIRED",
  })
  @DisplayName("Google subscriptionState > 구독 상태 (모르는 값은 Pro 아님)")
  void googleState_mapsToState(String subscriptionState, StorePurchaseState expected) {
    assertThat(GoogleSubscriptionSnapshotMapper.stateOf(subscriptionState)).isEqualTo(expected);
  }

  @Test
  @DisplayName("Google: 조회 결과 > 만료일·자동 갱신·테스트 결제·구매 확인 필요·회원 id")
  void googlePurchase_isMapped() throws Exception {
    JsonNode purchase = DefaultJsonMapper.SHARED.readTree("""
      {"subscriptionState":"SUBSCRIPTION_STATE_ACTIVE","acknowledgementState":"ACKNOWLEDGEMENT_STATE_PENDING",
       "testPurchase":{},"externalAccountIdentifiers":{"obfuscatedExternalAccountId":"member-1"},
       "lineItems":[{"productId":"elum_pro_monthly","expiryTime":"2026-12-05T03:00:00Z",
                     "autoRenewingPlan":{"autoRenewEnabled":true},"latestSuccessfulOrderId":"GPA.1234"}]}
      """);

    StoreSubscriptionSnapshot snapshot = GoogleSubscriptionSnapshotMapper.toSnapshot(purchase, "token-1", null, NOW);

    assertThat(snapshot.state()).isEqualTo(StorePurchaseState.ACTIVE);
    assertThat(snapshot.environment()).isEqualTo(StoreEnvironment.SANDBOX);
    assertThat(snapshot.needsAcknowledge()).isTrue();
    assertThat(snapshot.willAutoRenew()).isTrue();
    assertThat(snapshot.appAccountId()).isEqualTo("member-1");
    assertThat(snapshot.latestTransactionId()).isEqualTo("GPA.1234");
    assertThat(snapshot.expiresAt()).isEqualTo(
      LocalDateTime.ofInstant(java.time.Instant.parse("2026-12-05T03:00:00Z"), ZoneId.systemDefault()));
  }

  @Test
  @DisplayName("Google: REVOKED(12) 알림은 조회 결과가 아직 이용 중이어도 회수")
  void googleRevokedNotification_isRevoked() throws Exception {
    JsonNode purchase = DefaultJsonMapper.SHARED.readTree("""
      {"subscriptionState":"SUBSCRIPTION_STATE_ACTIVE","lineItems":[{"productId":"p","expiryTime":"2026-12-05T03:00:00Z"}]}
      """);

    StoreSubscriptionSnapshot snapshot = GoogleSubscriptionSnapshotMapper.toSnapshot(purchase, "token-1", 12, NOW);

    assertThat(snapshot.state()).isEqualTo(StorePurchaseState.REVOKED);
    assertThat(snapshot.revokedAt()).isEqualTo(NOW);
    assertThat(GoogleSubscriptionSnapshotMapper.notificationTypeName(12)).isEqualTo("SUBSCRIPTION_REVOKED");
    assertThat(GoogleSubscriptionSnapshotMapper.notificationTypeName(99)).isEqualTo("SUBSCRIPTION_UNKNOWN_99");
  }

  private static JWSTransactionDecodedPayload transaction(LocalDateTime expiresAt) {
    JWSTransactionDecodedPayload transaction = new JWSTransactionDecodedPayload();
    transaction.setOriginalTransactionId("1000000000000001");
    transaction.setTransactionId("2000000000000001");
    transaction.setProductId("elum_pro_monthly");
    transaction.setExpiresDate(millis(expiresAt));
    transaction.setSignedDate(millis(NOW));
    return transaction;
  }

  private static long millis(LocalDateTime time) {
    return time.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli();
  }
}
