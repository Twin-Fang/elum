package com.chuseok22.elumserver.license.infrastructure.store.google;

import com.fasterxml.jackson.databind.JsonNode;
import java.util.Optional;

/**
 * Google Play Developer API: 구독 조회(purchases.subscriptionsv2.get), 구매 확인(acknowledge), 자동 갱신 해지(subscriptionsv2.cancel)
 * 시간 초과·5xx·인증 실패는 StoreTemporarilyUnavailableException, 없는 토큰은 빈 값
 */
public interface GooglePlayDeveloperClient {

  /// SubscriptionPurchaseV2 JSON
  Optional<JsonNode> fetchSubscription(String packageName, String purchaseToken, String serviceAccountJson);

  /// 3일 안에 확인하지 않으면 Google 이 자동 환불한다
  void acknowledge(String packageName, String productId, String purchaseToken, String serviceAccountJson);

  /// 다음 갱신만 멈춤 (이미 낸 기간은 유지, 환불 없음). 실패는 StoreTemporarilyUnavailableException
  void cancelSubscription(String packageName, String purchaseToken, String serviceAccountJson);
}
