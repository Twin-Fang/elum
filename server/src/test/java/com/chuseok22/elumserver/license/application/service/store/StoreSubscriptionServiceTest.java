package com.chuseok22.elumserver.license.application.service.store;

import static com.chuseok22.elumserver.license.infrastructure.store.apple.AppleJwsTestFixtures.APP_APPLE_ID;
import static com.chuseok22.elumserver.license.infrastructure.store.apple.AppleJwsTestFixtures.BUNDLE_ID;
import static com.chuseok22.elumserver.license.infrastructure.store.apple.AppleJwsTestFixtures.PRODUCT_ID;
import static com.chuseok22.elumserver.license.infrastructure.store.apple.AppleJwsTestFixtures.TRUSTED;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.application.service.store.StoreSubscriptionSettings.AppleServerApiCredentials;
import com.chuseok22.elumserver.license.core.PlanType;
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
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 스토어 구독 서비스 경계: 꺼짐(운영 기본값), Sandbox 거부, Apple 시간 초과 > 확인 중(Pro 안 줌), 알림 서명·토큰, 끝까지 반영
 * 서명 검증은 시험용 루트를 믿는 실제 검증기, 저장은 메모리 저장소, 스토어 API 는 mock (실제 Apple·Google 호출 없음)
 */
class StoreSubscriptionServiceTest {

  private static final String MEMBER_ID = "aaaaaaaa-0000-4000-8000-000000000001";
  private static final String PUSH_TOKEN = "push-token-123";
  private static final long ONE_DAY_MILLIS = 86_400_000L;

  private final StoreSubscriptionSettings settings = mock(StoreSubscriptionSettings.class);
  private final AppleSubscriptionStatusClient statusClient = mock(AppleSubscriptionStatusClient.class);
  private final GooglePlayDeveloperClient playClient = mock(GooglePlayDeveloperClient.class);
  private StoreSubscriptionTestStore store;
  private AppleSubscriptionService appleService;
  private GoogleSubscriptionService googleService;

  @BeforeEach
  void setUp() {
    store = new StoreSubscriptionTestStore();
    store.addMember(MEMBER_ID, MemberStatus.ACTIVE);
    when(settings.appleBundleId()).thenReturn(BUNDLE_ID);
    when(settings.appleAppAppleId()).thenReturn(APP_APPLE_ID);
    when(settings.appleProductIds()).thenReturn(Set.of(PRODUCT_ID));
    when(settings.googlePackageName()).thenReturn(BUNDLE_ID);
    when(settings.googleProductIds()).thenReturn(Set.of(PRODUCT_ID));
    when(settings.googleRtdnPushToken()).thenReturn(PUSH_TOKEN);
    Clock clock = Clock.systemDefaultZone();
    appleService = new AppleSubscriptionService(settings,
      new AppleSignedDataVerifier(AppleJwsTestFixtures.trustedRoots()), statusClient, store.applier, mock(StoreConsumableRefundHandler.class), clock);
    googleService = new GoogleSubscriptionService(settings, playClient, store.applier, mock(StoreConsumableRefundHandler.class), clock);
  }

  @Test
  @DisplayName("운영 기본값(꺼짐): 앱 검증은 SUBSCRIPTION_STORE_DISABLED, 알림은 503 — 배포만으로 동작이 바뀌지 않는다")
  void disabledFlags_rejectEverything() {
    assertErrorCode(() -> appleService.verifyFromClient(MEMBER_ID, "x", null), ErrorCode.SUBSCRIPTION_STORE_DISABLED);
    assertErrorCode(() -> googleService.verifyFromClient(MEMBER_ID, "t", PRODUCT_ID), ErrorCode.SUBSCRIPTION_STORE_DISABLED);
    assertThat(appleService.handleNotification("x")).isEqualTo(StoreNotificationOutcome.RETRY_LATER);
    assertThat(googleService.handleNotification(PUSH_TOKEN, "{}")).isEqualTo(StoreNotificationOutcome.RETRY_LATER);
    assertThat(store.purchasesByKey).isEmpty();
  }

  @Test
  @DisplayName("App Store 실제 결제 검증 > Pro 이용 중, 회원 구독이 App Store 로 바뀐다")
  void appleVerify_grantsPro() {
    when(settings.isAppleEnabled()).thenReturn(true);

    StoreVerification verification = appleService.verifyFromClient(MEMBER_ID, signedTransaction("Production"), null);

    assertThat(verification).isEqualTo(StoreVerification.ACTIVE);
    assertThat(store.subscriptionsByMemberId.get(MEMBER_ID).getSource()).isEqualTo(SubscriptionSource.APPLE_IAP);
    assertThat(store.subscriptionsByMemberId.get(MEMBER_ID).effectivePlan(java.time.LocalDateTime.now())).isEqualTo(PlanType.PRO);
  }

  @Test
  @DisplayName("Sandbox 결제를 테스트 결제 허용 없이 보내면 400 SUBSCRIPTION_ENVIRONMENT_NOT_ALLOWED, Pro 없음")
  void appleSandboxInProduction_isRejected() {
    when(settings.isAppleEnabled()).thenReturn(true);

    assertErrorCode(() -> appleService.verifyFromClient(MEMBER_ID, signedTransaction("Sandbox"), null),
      ErrorCode.SUBSCRIPTION_ENVIRONMENT_NOT_ALLOWED);
    assertThat(store.subscriptionsByMemberId).isEmpty();
  }

  @Test
  @DisplayName("Apple 재조회가 시간 초과면 PENDING — Pro 를 주지 않고 구매 기록도 바꾸지 않는다")
  void appleApiTimeout_isPendingWithoutGrant() {
    when(settings.isAppleEnabled()).thenReturn(true);
    when(settings.appleServerApiCredentials()).thenReturn(new AppleServerApiCredentials("issuer", "key", "pem"));
    when(statusClient.fetchLatest(anyString(), any(), anyString(), any()))
      .thenThrow(new StoreTemporarilyUnavailableException("timeout"));

    StoreVerification verification = appleService.verifyFromClient(MEMBER_ID, signedTransaction("Production"), null);

    assertThat(verification).isEqualTo(StoreVerification.PENDING);
    assertThat(store.purchasesByKey).isEmpty();
    assertThat(store.subscriptionsByMemberId).isEmpty();
  }

  @Test
  @DisplayName("App Store 알림: 위조 서명은 400 거부, 진짜 알림은 처리되어 앱 호출 없이도 Pro 가 켜진다")
  void appleNotification_signatureDecides() {
    when(settings.isAppleEnabled()).thenReturn(true);
    String transaction = signedTransaction("Production");
    var payload = AppleJwsTestFixtures.notification("SUBSCRIBED", "INITIAL_BUY", UUID.randomUUID().toString(),
      "Production", APP_APPLE_ID, transaction, null);

    assertThat(appleService.handleNotification(AppleJwsTestFixtures.sign(AppleJwsTestFixtures.ATTACKER, payload)))
      .isEqualTo(StoreNotificationOutcome.REJECTED);
    assertThat(store.purchasesByKey).isEmpty();

    assertThat(appleService.handleNotification(AppleJwsTestFixtures.sign(TRUSTED, payload)))
      .isEqualTo(StoreNotificationOutcome.PROCESSED);
    assertThat(store.subscriptionsByMemberId.get(MEMBER_ID).getSource()).isEqualTo(SubscriptionSource.APPLE_IAP);
  }

  @Test
  @DisplayName("Google 알림: 토큰이 비었거나 틀리면 403, Google 조회가 실패하면 503 (Pub/Sub 재전송)")
  void googleNotification_tokenAndRetry() {
    when(settings.isGoogleEnabled()).thenReturn(true);
    when(settings.googleServiceAccountJson()).thenReturn("{}");
    when(playClient.fetchSubscription(anyString(), anyString(), anyString()))
      .thenThrow(new StoreTemporarilyUnavailableException("timeout"));
    String body = pubSubBody("""
      {"packageName":"%s","subscriptionNotification":{"notificationType":2,"purchaseToken":"token-1"}}
      """.formatted(BUNDLE_ID));

    assertThat(googleService.handleNotification(null, body)).isEqualTo(StoreNotificationOutcome.FORBIDDEN);
    assertThat(googleService.handleNotification("wrong", body)).isEqualTo(StoreNotificationOutcome.FORBIDDEN);
    assertThat(googleService.handleNotification(PUSH_TOKEN, body)).isEqualTo(StoreNotificationOutcome.RETRY_LATER);
    assertThat(store.events).isEmpty();
  }

  @Test
  @DisplayName("Google 검증: 허용 목록에 없는 상품은 Google 에 묻기 전에 400 SUBSCRIPTION_PRODUCT_NOT_ALLOWED")
  void googleUnknownProduct_isRejected() {
    when(settings.isGoogleEnabled()).thenReturn(true);
    when(settings.googleServiceAccountJson()).thenReturn("{}");

    assertErrorCode(() -> googleService.verifyFromClient(MEMBER_ID, "token-1", "other_product"),
      ErrorCode.SUBSCRIPTION_PRODUCT_NOT_ALLOWED);
  }

  private static String signedTransaction(String environment) {
    return AppleJwsTestFixtures.sign(TRUSTED, AppleJwsTestFixtures.transaction("1000000000000001", "2000000000000001",
      environment, Instant.now().toEpochMilli() + 30 * ONE_DAY_MILLIS, MEMBER_ID));
  }

  private static String pubSubBody(String notificationJson) {
    String data = Base64.getEncoder().encodeToString(notificationJson.getBytes(StandardCharsets.UTF_8));
    return "{\"message\":{\"data\":\"" + data + "\",\"messageId\":\"m-1\"},\"subscription\":\"s\"}";
  }

  private static void assertErrorCode(Runnable call, ErrorCode errorCode) {
    assertThatThrownBy(call::run)
      .isInstanceOfSatisfying(CustomException.class, e -> assertThat(e.getErrorCode()).isEqualTo(errorCode));
  }
}
