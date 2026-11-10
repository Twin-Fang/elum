package com.chuseok22.elumserver.credit.application.service.purchase;

import static com.chuseok22.elumserver.license.infrastructure.store.apple.AppleJwsTestFixtures.APP_APPLE_ID;
import static com.chuseok22.elumserver.license.infrastructure.store.apple.AppleJwsTestFixtures.BUNDLE_ID;
import static com.chuseok22.elumserver.license.infrastructure.store.apple.AppleJwsTestFixtures.TRUSTED;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.json.DefaultJsonMapper;
import com.chuseok22.elumserver.credit.application.dto.response.CreditPurchaseResponse;
import com.chuseok22.elumserver.credit.core.CreditPurchaseResultStatus;
import com.chuseok22.elumserver.license.application.service.store.StoreSubscriptionSettings;
import com.chuseok22.elumserver.license.application.service.store.StoreTemporarilyUnavailableException;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.infrastructure.store.apple.AppleJwsTestFixtures;
import com.chuseok22.elumserver.license.infrastructure.store.apple.AppleSignedDataVerifier;
import com.chuseok22.elumserver.license.infrastructure.store.apple.AppleSignedDataVerifier.AppleVerifyContext;
import com.chuseok22.elumserver.license.infrastructure.store.google.GooglePlayDeveloperClient;
import com.fasterxml.jackson.databind.JsonNode;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 스토어 구매 확인 경계: 판매 꺼짐·꾸러미 밖 상품·소모성 아님·위조 서명 거절, 결제 보류는 적립하지 않음, 소비 실패는 적립 유지
class CreditPurchaseStoreServiceTest {

  private static final String MEMBER_ID = "member-a";
  private static final String PRODUCT_ID = "elum_credit_150";

  private final CreditPackCatalog packCatalog = mock(CreditPackCatalog.class);
  private final StoreSubscriptionSettings settings = mock(StoreSubscriptionSettings.class);
  private final CreditPurchaseGrantService grantService = mock(CreditPurchaseGrantService.class);
  private final GooglePlayDeveloperClient playClient = mock(GooglePlayDeveloperClient.class);
  private AppleCreditPurchaseService appleService;
  private GoogleCreditPurchaseService googleService;

  @BeforeEach
  void setUp() {
    when(packCatalog.isSaleEnabled()).thenReturn(true);
    when(settings.isAppleEnabled()).thenReturn(true);
    when(settings.isGoogleEnabled()).thenReturn(true);
    when(settings.appleVerifyContext()).thenReturn(new AppleVerifyContext(BUNDLE_ID, APP_APPLE_ID, true));
    when(settings.googleServiceAccountJson()).thenReturn("{}");
    when(settings.googlePackageName()).thenReturn(BUNDLE_ID);
    when(packCatalog.findPack(PRODUCT_ID)).thenReturn(Optional.of(new com.chuseok22.elumserver.systemconfig.core.CreditPackListFormat.Pack(PRODUCT_ID, 150)));
    appleService = new AppleCreditPurchaseService(packCatalog, settings,
      new AppleSignedDataVerifier(AppleJwsTestFixtures.trustedRoots()), grantService);
    googleService = new GoogleCreditPurchaseService(packCatalog, settings, playClient, grantService);
    when(grantService.grantOnce(anyString(), any(), anyString(), anyString()))
      .thenReturn(new CreditPurchaseResponse(CreditPurchaseResultStatus.GRANTED, 150, 150));
  }

  // --- 판매 스위치 ---

  @Test
  @DisplayName("판매가 꺼져 있으면 두 스토어 모두 구매 확인을 거절한다 — 켜기 전에 들어온 결제로 적립되지 않는다")
  void saleOff_rejectsBothStores() {
    when(packCatalog.isSaleEnabled()).thenReturn(false);

    assertErrorCode(() -> appleService.verify(MEMBER_ID, "jws"), ErrorCode.CREDIT_PACK_SALE_DISABLED);
    assertErrorCode(() -> googleService.verify(MEMBER_ID, PRODUCT_ID, "token"), ErrorCode.CREDIT_PACK_SALE_DISABLED);
    verifyNoInteractions(grantService, playClient);
  }

  // --- Apple ---

  private static String signedConsumable(String chain, String productId, String type) {
    Map<String, Object> payload = AppleJwsTestFixtures.transaction("3000000000000001", "3000000000000001",
      "Production", Instant.now().toEpochMilli() + 1000, null);
    payload.remove("expiresDate");
    payload.put("type", type);
    payload.put("productId", productId);
    return AppleJwsTestFixtures.sign(chain, payload);
  }

  @Test
  @DisplayName("Apple 소모성 거래는 서명이 맞으면 거래 id·상품으로 적립을 맡긴다")
  void apple_consumable_grantsByTransactionId() {
    CreditPurchaseResponse response = appleService.verify(MEMBER_ID, signedConsumable(TRUSTED, PRODUCT_ID, "Consumable"));

    assertThat(response.status()).isEqualTo(CreditPurchaseResultStatus.GRANTED);
    verify(grantService).grantOnce(MEMBER_ID, SubscriptionSource.APPLE_IAP, "3000000000000001", PRODUCT_ID);
  }

  @Test
  @DisplayName("구독 거래로 크레딧 구매를 확인하면 거절한다 — 구독 영수증으로 크레딧을 받을 수 없다")
  void apple_subscriptionTransaction_isRejected() {
    assertErrorCode(() -> appleService.verify(MEMBER_ID, signedConsumable(TRUSTED, PRODUCT_ID, "Auto-Renewable Subscription")),
      ErrorCode.SUBSCRIPTION_RECEIPT_INVALID);
    verifyNoInteractions(grantService);
  }

  @Test
  @DisplayName("믿지 않는 체인으로 서명한 위조 거래는 거절한다")
  void apple_forgedSignature_isRejected() {
    assertErrorCode(() -> appleService.verify(MEMBER_ID, signedConsumable(AppleJwsTestFixtures.ATTACKER, PRODUCT_ID, "Consumable")),
      ErrorCode.SUBSCRIPTION_RECEIPT_INVALID);
    verifyNoInteractions(grantService);
  }

  // --- Google ---

  private static JsonNode purchase(int purchaseState, int consumptionState) {
    return json("{\"purchaseState\":" + purchaseState + ",\"consumptionState\":" + consumptionState
      + ",\"orderId\":\"GPA.1111-2222-3333-44444\",\"productId\":\"" + PRODUCT_ID + "\"}");
  }

  private static JsonNode json(String text) {
    try {
      return DefaultJsonMapper.SHARED.readTree(text);
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }

  @Test
  @DisplayName("Google 결제 완료 구매는 주문 id 로 적립하고 소비한다")
  void google_purchased_grantsByOrderIdAndConsumes() {
    when(playClient.fetchProductPurchase(BUNDLE_ID, PRODUCT_ID, "token", "{}")).thenReturn(Optional.of(purchase(0, 0)));

    CreditPurchaseResponse response = googleService.verify(MEMBER_ID, PRODUCT_ID, "token");

    assertThat(response.status()).isEqualTo(CreditPurchaseResultStatus.GRANTED);
    verify(grantService).grantOnce(MEMBER_ID, SubscriptionSource.GOOGLE_IAP, "GPA.1111-2222-3333-44444", PRODUCT_ID);
    verify(playClient).consumeProduct(BUNDLE_ID, PRODUCT_ID, "token", "{}");
  }

  @Test
  @DisplayName("결제 보류(pending) 구매는 적립하지 않고 PENDING 으로 답한다 — 결제가 끝나기 전에 크레딧을 주지 않는다")
  void google_pendingPurchase_doesNotGrant() {
    when(playClient.fetchProductPurchase(BUNDLE_ID, PRODUCT_ID, "token", "{}")).thenReturn(Optional.of(purchase(2, 0)));
    when(grantService.availableOf(MEMBER_ID)).thenReturn(34);

    CreditPurchaseResponse response = googleService.verify(MEMBER_ID, PRODUCT_ID, "token");

    assertThat(response).isEqualTo(new CreditPurchaseResponse(CreditPurchaseResultStatus.PENDING, 0, 34));
    verify(grantService, never()).grantOnce(anyString(), any(), anyString(), anyString());
  }

  @Test
  @DisplayName("소비 호출이 실패해도 적립은 유지하고 같은 요청을 다시 받으면 소비를 다시 시도한다")
  void google_consumeFailure_keepsGrantAndRetriesNextRequest() {
    when(playClient.fetchProductPurchase(BUNDLE_ID, PRODUCT_ID, "token", "{}")).thenReturn(Optional.of(purchase(0, 0)));
    doThrow(new StoreTemporarilyUnavailableException("consume 500")).doNothing()
      .when(playClient).consumeProduct(anyString(), anyString(), anyString(), anyString());

    CreditPurchaseResponse first = googleService.verify(MEMBER_ID, PRODUCT_ID, "token");
    googleService.verify(MEMBER_ID, PRODUCT_ID, "token");

    assertThat(first.status()).isEqualTo(CreditPurchaseResultStatus.GRANTED);
    verify(playClient, times(2)).consumeProduct(BUNDLE_ID, PRODUCT_ID, "token", "{}");
  }

  @Test
  @DisplayName("Google 확인이 늦으면 PENDING 이다 — 구매를 버리지 않고 나중에 다시 확인한다")
  void google_storeUnavailable_returnsPending() {
    when(playClient.fetchProductPurchase(BUNDLE_ID, PRODUCT_ID, "token", "{}"))
      .thenThrow(new StoreTemporarilyUnavailableException("status 503"));

    assertThat(googleService.verify(MEMBER_ID, PRODUCT_ID, "token").status()).isEqualTo(CreditPurchaseResultStatus.PENDING);
    verify(grantService, never()).grantOnce(anyString(), any(), anyString(), anyString());
  }

  @Test
  @DisplayName("취소된 구매·꾸러미에 없는 상품은 거절한다")
  void google_canceledOrUnknownProduct_isRejected() {
    when(playClient.fetchProductPurchase(BUNDLE_ID, PRODUCT_ID, "token", "{}")).thenReturn(Optional.of(purchase(1, 0)));

    assertErrorCode(() -> googleService.verify(MEMBER_ID, PRODUCT_ID, "token"), ErrorCode.SUBSCRIPTION_RECEIPT_INVALID);
    assertErrorCode(() -> googleService.verify(MEMBER_ID, "elum_pro_monthly", "token"), ErrorCode.SUBSCRIPTION_PRODUCT_NOT_ALLOWED);
    verify(playClient, never()).consumeProduct(anyString(), anyString(), anyString(), anyString());
  }

  private static void assertErrorCode(Runnable call, ErrorCode errorCode) {
    assertThatThrownBy(call::run)
      .isInstanceOfSatisfying(CustomException.class, e -> assertThat(e.getErrorCode()).isEqualTo(errorCode));
  }
}
