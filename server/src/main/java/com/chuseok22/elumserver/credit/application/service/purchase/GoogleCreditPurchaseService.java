package com.chuseok22.elumserver.credit.application.service.purchase;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.credit.application.dto.response.CreditPurchaseResponse;
import com.chuseok22.elumserver.license.application.service.store.StoreLogValues;
import com.chuseok22.elumserver.license.application.service.store.StoreSubscriptionSettings;
import com.chuseok22.elumserver.license.application.service.store.StoreTemporarilyUnavailableException;
import com.chuseok22.elumserver.license.application.service.store.StoreVerifyRejectedException;
import com.chuseok22.elumserver.license.core.StoreVerifyRejectReason;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.infrastructure.entity.StorePurchase;
import com.chuseok22.elumserver.license.infrastructure.store.google.GooglePlayDeveloperClient;
import com.fasterxml.jackson.databind.JsonNode;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * Google Play 크레딧 구매 확인: 판매 켜짐 > 꾸러미 상품 > 상품 구매 조회 > 결제 완료·테스트 결제 확인 > 적립 > 소비(consume)
 * 소비 실패는 적립을 되돌리지 않고, 같은 구매가 다시 확인될 때 다시 시도한다. 스토어 조회가 늦으면 PENDING
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class GoogleCreditPurchaseService {

  private static final int MAX_PRODUCT_ID_LENGTH = 150;
  /// ProductPurchase.purchaseState: 0 결제 완료, 1 취소, 2 보류
  private static final int PURCHASE_STATE_PURCHASED = 0;
  private static final int PURCHASE_STATE_PENDING = 2;
  /// ProductPurchase.consumptionState: 1 소비됨
  private static final int CONSUMPTION_STATE_CONSUMED = 1;
  /// ProductPurchase.purchaseType: 0 테스트 결제 (실제 결제는 값이 없음)
  private static final int PURCHASE_TYPE_TEST = 0;

  private final CreditPackCatalog packCatalog;
  private final StoreSubscriptionSettings settings;
  private final GooglePlayDeveloperClient playClient;
  private final CreditPurchaseGrantService grantService;

  /**
   * @throws CustomException 판매·스토어 꺼짐 403, 형식·상품·테스트 결제·취소된 구매·다른 계정 거래 400, 서비스 계정 없음 503
   */
  public CreditPurchaseResponse verify(String memberId, String productId, String purchaseToken) {
    if (!packCatalog.isSaleEnabled()) {
      throw new CustomException(ErrorCode.CREDIT_PACK_SALE_DISABLED);
    }
    if (!settings.isGoogleEnabled()) {
      throw new CustomException(ErrorCode.SUBSCRIPTION_STORE_DISABLED);
    }
    String serviceAccountJson = settings.googleServiceAccountJson();
    if (serviceAccountJson.isEmpty()) {
      log.error("[credit purchase] google service account not configured");
      throw new CustomException(ErrorCode.SUBSCRIPTION_STORE_NOT_CONFIGURED);
    }
    try {
      String product = requireText(productId, MAX_PRODUCT_ID_LENGTH);
      String token = requireText(purchaseToken, StorePurchase.PURCHASE_KEY_MAX_LENGTH);
      if (packCatalog.findPack(product).isEmpty()) {
        throw new StoreVerifyRejectedException(StoreVerifyRejectReason.PRODUCT_NOT_ALLOWED, null);
      }
      JsonNode purchase = playClient.fetchProductPurchase(settings.googlePackageName(), product, token, serviceAccountJson)
        .orElseThrow(() -> new StoreVerifyRejectedException(StoreVerifyRejectReason.PURCHASE_NOT_FOUND, null));
      if (purchase.path("purchaseState").asInt(PURCHASE_STATE_PURCHASED) == PURCHASE_STATE_PENDING) {
        return CreditPurchaseResponse.pending(grantService.availableOf(memberId));
      }
      requirePaidAndAllowed(purchase, product);

      CreditPurchaseResponse result = grantService.grantOnce(
        memberId, SubscriptionSource.GOOGLE_IAP, purchase.path("orderId").asText(), product);
      consumeIfNeeded(purchase, product, token, serviceAccountJson);
      return result;
    } catch (StoreVerifyRejectedException e) {
      log.warn("[credit purchase] rejected 400 : {} : store=GOOGLE_IAP, member={}",
        e.getReason(), StoreLogValues.mask(memberId));
      throw new CustomException(e.getReason().getErrorCode());
    } catch (StoreTemporarilyUnavailableException e) {
      log.warn("[credit purchase] pending : store=GOOGLE_IAP, member={}, cause={}", StoreLogValues.mask(memberId), e.getMessage());
      return CreditPurchaseResponse.pending(grantService.availableOf(memberId));
    }
  }

  // 결제 완료 상태·상품 일치·거래 id·테스트 결제 허용 확인
  private void requirePaidAndAllowed(JsonNode purchase, String product) {
    if (purchase.path("purchaseState").asInt(PURCHASE_STATE_PURCHASED) != PURCHASE_STATE_PURCHASED) {
      throw new StoreVerifyRejectedException(StoreVerifyRejectReason.PURCHASE_NOT_FOUND, "canceled");
    }
    if (purchase.hasNonNull("productId") && !product.equals(purchase.path("productId").asText())) {
      throw new StoreVerifyRejectedException(StoreVerifyRejectReason.MALFORMED, "product mismatch");
    }
    if (purchase.path("orderId").asText("").isBlank()) {
      throw new StoreVerifyRejectedException(StoreVerifyRejectReason.MALFORMED, "orderId");
    }
    boolean isTestPurchase = purchase.path("purchaseType").isInt() && purchase.path("purchaseType").asInt() == PURCHASE_TYPE_TEST;
    if (isTestPurchase && !settings.isGoogleTestPurchaseAllowed()) {
      throw new StoreVerifyRejectedException(StoreVerifyRejectReason.ENVIRONMENT_NOT_ALLOWED, "test purchase");
    }
  }

  // 적립 뒤 소비 (이미 소비됐으면 건너뜀). 실패해도 적립은 유지하고 다음 확인 요청에서 다시 시도
  private void consumeIfNeeded(JsonNode purchase, String product, String token, String serviceAccountJson) {
    if (purchase.path("consumptionState").asInt(0) == CONSUMPTION_STATE_CONSUMED) {
      return;
    }
    try {
      playClient.consumeProduct(settings.googlePackageName(), product, token, serviceAccountJson);
    } catch (StoreTemporarilyUnavailableException e) {
      log.warn("[credit purchase] google consume failed, retry next time : purchase={}", StoreLogValues.mask(token));
    }
  }

  private static String requireText(String value, int maxLength) {
    if (value == null || value.isBlank() || value.length() > maxLength) {
      throw new StoreVerifyRejectedException(StoreVerifyRejectReason.MALFORMED, "length");
    }
    return value.trim();
  }
}
