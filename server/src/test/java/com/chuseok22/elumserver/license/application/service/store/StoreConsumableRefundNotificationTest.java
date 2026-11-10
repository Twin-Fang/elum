package com.chuseok22.elumserver.license.application.service.store;

import static com.chuseok22.elumserver.license.infrastructure.store.apple.AppleJwsTestFixtures.APP_APPLE_ID;
import static com.chuseok22.elumserver.license.infrastructure.store.apple.AppleJwsTestFixtures.BUNDLE_ID;
import static com.chuseok22.elumserver.license.infrastructure.store.apple.AppleJwsTestFixtures.TRUSTED;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.infrastructure.store.apple.AppleJwsTestFixtures;
import com.chuseok22.elumserver.license.infrastructure.store.apple.AppleSignedDataVerifier;
import com.chuseok22.elumserver.license.infrastructure.store.apple.AppleSubscriptionStatusClient;
import com.chuseok22.elumserver.license.infrastructure.store.google.GooglePlayDeveloperClient;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Instant;
import java.util.Base64;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 소모성 상품 환불 알림이 크레딧 회수로 이어지는가: 서명 검증을 거친 환불만, 구독 알림 경로는 그대로
class StoreConsumableRefundNotificationTest {

  private static final String PUSH_TOKEN = "push-token-123";

  private final StoreSubscriptionSettings settings = mock(StoreSubscriptionSettings.class);
  private final StoreConsumableRefundHandler refundHandler = mock(StoreConsumableRefundHandler.class);
  private AppleSubscriptionService appleService;
  private GoogleSubscriptionService googleService;

  @BeforeEach
  void setUp() {
    StoreSubscriptionTestStore store = new StoreSubscriptionTestStore();
    store.addMember("aaaaaaaa-0000-4000-8000-000000000001", MemberStatus.ACTIVE);
    when(settings.isAppleEnabled()).thenReturn(true);
    when(settings.isGoogleEnabled()).thenReturn(true);
    when(settings.isAppleSandboxAllowed()).thenReturn(true);
    when(settings.appleBundleId()).thenReturn(BUNDLE_ID);
    when(settings.appleAppAppleId()).thenReturn(APP_APPLE_ID);
    when(settings.googlePackageName()).thenReturn(BUNDLE_ID);
    when(settings.googleRtdnPushToken()).thenReturn(PUSH_TOKEN);
    Clock clock = Clock.systemDefaultZone();
    appleService = new AppleSubscriptionService(settings, new AppleSignedDataVerifier(AppleJwsTestFixtures.trustedRoots()),
      mock(AppleSubscriptionStatusClient.class), store.applier, refundHandler, clock);
    googleService = new GoogleSubscriptionService(settings, mock(GooglePlayDeveloperClient.class), store.applier,
      refundHandler, clock);
  }

  private String appleNotification(String type) {
    Map<String, Object> transaction = AppleJwsTestFixtures.transaction("4000000000000001", "4000000000000001",
      "Production", 0L, null);
    transaction.remove("expiresDate");
    transaction.put("type", "Consumable");
    transaction.put("productId", "elum_credit_150");
    return AppleJwsTestFixtures.sign(TRUSTED, AppleJwsTestFixtures.notification(type, null, UUID.randomUUID().toString(),
      "Production", APP_APPLE_ID, AppleJwsTestFixtures.sign(TRUSTED, transaction), null));
  }

  @Test
  @DisplayName("Apple 소모성 거래의 REFUND 알림은 회수 처리를 부른다 — 환불받고도 크레딧이 남는다")
  void appleConsumableRefund_triggersRecovery() {
    assertThat(appleService.handleNotification(appleNotification("REFUND"))).isEqualTo(StoreNotificationOutcome.PROCESSED);

    verify(refundHandler).refund(SubscriptionSource.APPLE_IAP, "4000000000000001");
  }

  @Test
  @DisplayName("Apple 소모성 거래의 다른 알림(REFUND 아님)은 무시한다")
  void appleConsumableOtherNotification_isIgnored() {
    assertThat(appleService.handleNotification(appleNotification("CONSUMPTION_REQUEST"))).isEqualTo(StoreNotificationOutcome.IGNORED);

    verify(refundHandler, never()).refund(any(), any());
  }

  @Test
  @DisplayName("Google 일회성 상품 환불(voided) 알림은 주문 id 로 회수 처리를 부른다")
  void googleOneTimeVoided_triggersRecovery() {
    String notification = "{\"packageName\":\"" + BUNDLE_ID + "\",\"voidedPurchaseNotification\":"
      + "{\"purchaseToken\":\"tok\",\"orderId\":\"GPA.1111-2222-3333-44444\",\"productType\":2,\"refundType\":1}}";
    String data = Base64.getEncoder().encodeToString(notification.getBytes(StandardCharsets.UTF_8));
    String body = "{\"message\":{\"data\":\"" + data + "\",\"messageId\":\"m-" + Instant.now().toEpochMilli() + "\"},\"subscription\":\"s\"}";

    assertThat(googleService.handleNotification(PUSH_TOKEN, body)).isEqualTo(StoreNotificationOutcome.PROCESSED);

    verify(refundHandler).refund(SubscriptionSource.GOOGLE_IAP, "GPA.1111-2222-3333-44444");
  }
}
