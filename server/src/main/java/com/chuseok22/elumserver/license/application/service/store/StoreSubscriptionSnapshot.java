package com.chuseok22.elumserver.license.application.service.store;

import com.chuseok22.elumserver.license.core.StoreEnvironment;
import com.chuseok22.elumserver.license.core.StorePurchaseState;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import java.time.LocalDateTime;

/**
 * 스토어가 서명·조회로 확인해 준 구독 상태 (App Store·Google Play 공통 형태)
 * 검증을 통과한 값만 담음. 만들기는 AppleSubscriptionSnapshotMapper·GoogleSubscriptionSnapshotMapper
 *
 * @param purchaseKey       App Store originalTransactionId, Google purchaseToken
 * @param linkedPurchaseKey Google 업그레이드·재구독 전 purchaseToken, 없으면 null
 * @param appAccountId      구매 때 앱이 실은 회원 id (Apple appAccountToken, Google obfuscatedExternalAccountId)
 * @param willAutoRenew     모르면 null
 * @param storeSignedAt     스토어가 이 상태를 서명·조회한 시각
 * @param needsAcknowledge  Google 구매 확인(acknowledge)이 아직 안 됨
 */
public record StoreSubscriptionSnapshot(
  SubscriptionSource store,
  String purchaseKey,
  String linkedPurchaseKey,
  String productId,
  StoreEnvironment environment,
  String latestTransactionId,
  String appAccountId,
  LocalDateTime expiresAt,
  LocalDateTime gracePeriodExpiresAt,
  Boolean willAutoRenew,
  StorePurchaseState state,
  LocalDateTime revokedAt,
  LocalDateTime storeSignedAt,
  boolean needsAcknowledge
) {

  /// 상태만 바꾼 사본 (Google 환불 알림처럼 조회 결과에 회수를 덧씌울 때)
  public StoreSubscriptionSnapshot withRevoked(LocalDateTime revokedAt) {
    return new StoreSubscriptionSnapshot(store, purchaseKey, linkedPurchaseKey, productId, environment,
      latestTransactionId, appAccountId, expiresAt, gracePeriodExpiresAt, willAutoRenew,
      StorePurchaseState.REVOKED, revokedAt, storeSignedAt, needsAcknowledge);
  }
}
