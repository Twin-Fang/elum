package com.chuseok22.elumserver.license.application.service.store;

import static com.chuseok22.elumserver.license.infrastructure.store.apple.AppleJwsTestFixtures.APP_APPLE_ID;
import static com.chuseok22.elumserver.license.infrastructure.store.apple.AppleJwsTestFixtures.BUNDLE_ID;
import static com.chuseok22.elumserver.license.infrastructure.store.apple.AppleJwsTestFixtures.TRUSTED;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.license.application.service.refund.AppleRefundRecheck;
import com.chuseok22.elumserver.license.application.service.refund.GoogleRefundRecheck;
import com.chuseok22.elumserver.license.application.service.refund.RefundRecheckRevoker;
import com.chuseok22.elumserver.license.application.service.refund.StoreRefundRecheckService;
import com.chuseok22.elumserver.license.application.service.store.StoreConsumableRefundHandler.ConsumableRefundOutcome;
import com.chuseok22.elumserver.license.application.service.store.StorePurchaseApplier.StoreApplyOutcome;
import com.chuseok22.elumserver.license.application.service.store.StoreSubscriptionSettings.AppleServerApiCredentials;
import com.chuseok22.elumserver.license.core.ConsumableRefundResult;
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.core.StoreEnvironment;
import com.chuseok22.elumserver.license.core.StorePurchaseState;
import com.chuseok22.elumserver.license.core.StorePurchaseTrigger;
import com.chuseok22.elumserver.license.core.StoreRefundCheckFailureReason;
import com.chuseok22.elumserver.license.core.StoreRefundCheckTrigger;
import com.chuseok22.elumserver.license.core.StoreRefundOrigin;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.infrastructure.entity.StoreRefundCheckRun;
import com.chuseok22.elumserver.license.infrastructure.repository.StorePurchaseRepository;
import com.chuseok22.elumserver.license.infrastructure.repository.StoreRefundCheckRunRepository;
import com.chuseok22.elumserver.license.infrastructure.store.apple.AppleJwsTestFixtures;
import com.chuseok22.elumserver.license.infrastructure.store.apple.AppleSignedDataVerifier;
import com.chuseok22.elumserver.license.infrastructure.store.apple.AppleSignedDataVerifier.AppleVerifyContext;
import com.chuseok22.elumserver.license.infrastructure.store.apple.AppleSubscriptionStatusClient;
import com.chuseok22.elumserver.license.infrastructure.store.google.GooglePlayDeveloperClient;
import com.chuseok22.elumserver.license.infrastructure.store.google.GooglePlayDeveloperClient.VoidedPurchase;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 환불 재확인: 알림을 놓친 환불을 스토어에 다시 물어 Pro·크레딧을 회수하는가, 키가 없으면 부르지 않고 사유를 남기는가
class StoreRefundRecheckTest {

  private static final String MEMBER_ID = "aaaaaaaa-0000-4000-8000-000000000001";
  private static final String PURCHASE_TOKEN = "google-token-1";
  private static final String CREDIT_ORDER_ID = "GPA.9999-0000-0000-00001";
  private static final String APPLE_CREDIT_TRANSACTION_ID = "4000000000000001";
  private static final LocalDateTime NOW = StoreSubscriptionTestStore.NOW;

  private final StoreSubscriptionSettings settings = mock(StoreSubscriptionSettings.class);
  private final GooglePlayDeveloperClient playClient = mock(GooglePlayDeveloperClient.class);
  private final AppleSubscriptionStatusClient appleClient = mock(AppleSubscriptionStatusClient.class);
  private final StorePurchaseRepository recheckPurchaseRepository = mock(StorePurchaseRepository.class);
  private final StoreConsumableRefundHandler refundHandler = mock(StoreConsumableRefundHandler.class);
  private StoreSubscriptionTestStore store;
  private GoogleRefundRecheck googleRecheck;
  private AppleRefundRecheck appleRecheck;

  @BeforeEach
  void setUp() {
    store = new StoreSubscriptionTestStore();
    store.addMember(MEMBER_ID, MemberStatus.ACTIVE);
    when(settings.isGoogleEnabled()).thenReturn(true);
    when(settings.isAppleEnabled()).thenReturn(true);
    when(settings.googlePackageName()).thenReturn(BUNDLE_ID);
    when(settings.googleServiceAccountJson()).thenReturn("{}");
    when(settings.appleServerApiCredentials()).thenReturn(new AppleServerApiCredentials("issuer", "key", "pem"));
    when(settings.appleVerifyContext()).thenReturn(new AppleVerifyContext(BUNDLE_ID, APP_APPLE_ID, false));
    when(refundHandler.refund(any(), anyString(), any()))
      .thenReturn(new ConsumableRefundOutcome(ConsumableRefundResult.UNKNOWN, null));
    RefundRecheckRevoker revoker = new RefundRecheckRevoker(store.applier, refundHandler);
    googleRecheck = new GoogleRefundRecheck(settings, playClient, recheckPurchaseRepository, refundHandler, revoker);
    appleRecheck = new AppleRefundRecheck(settings, appleClient, new AppleSignedDataVerifier(AppleJwsTestFixtures.trustedRoots()),
      recheckPurchaseRepository, refundHandler, revoker);
  }

  @Test
  @DisplayName("Google 취소 구매 목록의 구독 토큰은 Pro 를 회수하고, 다음 날 같은 목록은 아무것도 다시 쓰지 않는다 — RTDN 을 놓치면 환불받고도 Pro 가 남는다")
  void googleVoidedSubscription_revokesPro() {
    givenGoogleProSubscription();
    when(playClient.listVoidedPurchases(eq(BUNDLE_ID), anyLong(), anyString()))
      .thenReturn(List.of(new VoidedPurchase(PURCHASE_TOKEN, "GPA.1111-0000-0000-00001")));
    when(playClient.findRefundedOrderIds(anyString(), any(), anyString())).thenReturn(Set.of());
    int eventsBefore = store.events.size();

    StoreRefundCheckRun first = runGoogle();
    StoreRefundCheckRun second = runGoogle();

    assertThat(store.purchase(SubscriptionSource.GOOGLE_IAP, PURCHASE_TOKEN).getState()).isEqualTo(StorePurchaseState.REVOKED);
    assertThat(store.subscriptionsByMemberId.get(MEMBER_ID).effectivePlan(NOW)).isNotEqualTo(PlanType.PRO);
    assertThat(first.isSucceeded()).isTrue();
    assertThat(first.getRevokedCount()).isEqualTo(1);
    assertThat(second.getRevokedCount()).isZero();
    assertThat(store.events.subList(eventsBefore, store.events.size())).singleElement()
      .satisfies(event -> assertThat(event.getTrigger()).isEqualTo(StorePurchaseTrigger.REFUND_RECHECK));
  }

  @Test
  @DisplayName("Google 주문이 권한 회수 없이 환불(REFUNDED)됐으면 크레딧을 회수한다 — 취소 구매 목록에는 이 환불이 나오지 않는다")
  void googleRefundedOrder_revokesCredits() {
    when(playClient.listVoidedPurchases(anyString(), anyLong(), anyString())).thenReturn(List.of());
    when(refundHandler.findGrantedTransactionIds(eq(SubscriptionSource.GOOGLE_IAP), any())).thenReturn(List.of(CREDIT_ORDER_ID));
    when(recheckPurchaseRepository.findByStoreAndStateInAndRevokedAtIsNull(any(), any())).thenReturn(List.of());
    when(playClient.findRefundedOrderIds(anyString(), any(), anyString())).thenReturn(Set.of(CREDIT_ORDER_ID));
    when(refundHandler.refund(SubscriptionSource.GOOGLE_IAP, CREDIT_ORDER_ID, StoreRefundOrigin.REFUND_RECHECK))
      .thenReturn(new ConsumableRefundOutcome(ConsumableRefundResult.REVOKED, MEMBER_ID));

    StoreRefundCheckRun run = runGoogle();

    assertThat(run.isSucceeded()).isTrue();
    assertThat(run.getCheckedCount()).isEqualTo(1);
    assertThat(run.getRefundedCount()).isEqualTo(1);
    assertThat(run.getRevokedCount()).isEqualTo(1);
    assertThat(store.events).singleElement().satisfies(event -> {
      assertThat(event.getTrigger()).isEqualTo(StorePurchaseTrigger.REFUND_RECHECK);
      assertThat(event.getTransactionId()).isEqualTo(CREDIT_ORDER_ID);
      assertThat(event.getMemberId()).isEqualTo(MEMBER_ID);
    });
  }

  @Test
  @DisplayName("App Store 가 회수 표시(revocationDate)한 크레딧 거래는 회수한다 — REFUND 알림을 놓쳐도 크레딧이 남지 않는다")
  void appleRevokedConsumable_revokesCredits() {
    when(refundHandler.findGrantedTransactionIds(eq(SubscriptionSource.APPLE_IAP), any()))
      .thenReturn(List.of(APPLE_CREDIT_TRANSACTION_ID));
    when(recheckPurchaseRepository.findByStoreAndStateInAndRevokedAtIsNull(any(), any())).thenReturn(List.of());
    when(appleClient.fetchSignedTransaction(eq(APPLE_CREDIT_TRANSACTION_ID), eq(StoreEnvironment.PRODUCTION), anyString(), any()))
      .thenReturn(Optional.of(revokedConsumableTransaction()));
    when(refundHandler.refund(SubscriptionSource.APPLE_IAP, APPLE_CREDIT_TRANSACTION_ID, StoreRefundOrigin.REFUND_RECHECK))
      .thenReturn(new ConsumableRefundOutcome(ConsumableRefundResult.REVOKED, MEMBER_ID));
    StoreRefundCheckRun run = StoreRefundCheckRun.start(SubscriptionSource.APPLE_IAP, StoreRefundCheckTrigger.SCHEDULED, null, NOW);

    appleRecheck.run(run);

    assertThat(run.isSucceeded()).isTrue();
    assertThat(run.getRefundedCount()).isEqualTo(1);
    assertThat(run.getRevokedCount()).isEqualTo(1);
  }

  @Test
  @DisplayName("키가 없으면 스토어를 부르지 않고 실행 기록에 사유를 남긴다 — 조용히 건너뛰면 관리자가 안 도는 줄 모른다")
  void missingCredentials_skipsWithReason() {
    when(settings.googleServiceAccountJson()).thenReturn("");
    when(settings.appleServerApiCredentials()).thenReturn(null);
    StoreRefundCheckRunRepository runRepository = mock(StoreRefundCheckRunRepository.class);
    StoreRefundRecheckService service = new StoreRefundRecheckService(googleRecheck, appleRecheck, runRepository, settings);

    List<StoreRefundCheckRun> runs = service.runAll(StoreRefundCheckTrigger.ADMIN, "admin");

    assertThat(runs).extracting(StoreRefundCheckRun::getFailureReason)
      .containsExactly(StoreRefundCheckFailureReason.CREDENTIALS_NOT_CONFIGURED, StoreRefundCheckFailureReason.CREDENTIALS_NOT_CONFIGURED);
    assertThat(runs).allSatisfy(run -> assertThat(run.getFinishedAt()).isNotNull());
    verify(runRepository, org.mockito.Mockito.times(2)).save(any(StoreRefundCheckRun.class));
    verify(playClient, never()).listVoidedPurchases(anyString(), anyLong(), anyString());
    verify(appleClient, never()).fetchSignedTransaction(anyString(), any(), anyString(), any());
  }

  private StoreRefundCheckRun runGoogle() {
    StoreRefundCheckRun run = StoreRefundCheckRun.start(SubscriptionSource.GOOGLE_IAP, StoreRefundCheckTrigger.SCHEDULED, null, NOW);
    googleRecheck.run(run);
    return run;
  }

  // Google 구독으로 Pro 이용 중인 회원 (앱 검증으로 묶음)
  private void givenGoogleProSubscription() {
    StoreSubscriptionSnapshot snapshot = new StoreSubscriptionSnapshot(SubscriptionSource.GOOGLE_IAP, PURCHASE_TOKEN, null,
      "elum_pro_monthly", StoreEnvironment.PRODUCTION, "GPA.1111-0000-0000-00001", null, NOW.plusDays(30), null, true,
      StorePurchaseState.ACTIVE, null, NOW.minusMinutes(1), false);
    StoreApplyOutcome outcome = store.applier.apply(snapshot, MEMBER_ID, StorePurchaseTrigger.CLIENT_VERIFY,
      StorePurchaseApplier.VERIFY_EVENT_TYPE, null);
    assertThat(outcome.purchase().isEntitled(NOW)).isTrue();
    assertThat(store.subscriptionsByMemberId.get(MEMBER_ID).effectivePlan(NOW)).isEqualTo(PlanType.PRO);
  }

  private static String revokedConsumableTransaction() {
    Map<String, Object> transaction = AppleJwsTestFixtures.transaction(APPLE_CREDIT_TRANSACTION_ID, APPLE_CREDIT_TRANSACTION_ID,
      "Production", 0L, null);
    transaction.remove("expiresDate");
    transaction.put("type", "Consumable");
    transaction.put("productId", "elum_credit_150");
    transaction.put("revocationDate", System.currentTimeMillis() - 60_000);
    transaction.put("revocationReason", 0);
    return AppleJwsTestFixtures.sign(TRUSTED, transaction);
  }
}
