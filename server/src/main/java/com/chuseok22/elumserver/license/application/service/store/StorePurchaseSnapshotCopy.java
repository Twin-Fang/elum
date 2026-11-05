package com.chuseok22.elumserver.license.application.service.store;

import com.chuseok22.elumserver.license.infrastructure.entity.StorePurchase;
import java.util.Objects;

/**
 * 스토어 스냅샷 > 구매 행: 새 행 만들기, 늦게 온 옛 정보 판정, 상태 복사(바뀜 여부)
 */
final class StorePurchaseSnapshotCopy {

  private StorePurchaseSnapshotCopy() {
  }

  static StorePurchase newPurchase(StoreSubscriptionSnapshot snapshot) {
    StorePurchase purchase = new StorePurchase();
    purchase.setStore(snapshot.store());
    purchase.setPurchaseKey(snapshot.purchaseKey());
    purchase.setEnvironment(snapshot.environment());
    purchase.setState(snapshot.state());
    return purchase;
  }

  // 이미 저장한 상태보다 스토어 서명 시각이 이른 정보 (늦게 도착한 옛 알림, 환불 전 영수증 재전송)
  static boolean isOlderThanStored(StorePurchase purchase, StoreSubscriptionSnapshot snapshot) {
    return purchase.getStoreSignedAt() != null && snapshot.storeSignedAt() != null
      && snapshot.storeSignedAt().isBefore(purchase.getStoreSignedAt());
  }

  /// 스냅샷 > 구매 행, 하나라도 바뀌었으면 true (회원 연결·확인 여부는 따로)
  static boolean copyState(StoreSubscriptionSnapshot snapshot, StorePurchase purchase) {
    boolean isChanged = purchase.getId() == null
      || !Objects.equals(purchase.getProductId(), snapshot.productId())
      || purchase.getEnvironment() != snapshot.environment()
      || purchase.getState() != snapshot.state()
      || !Objects.equals(purchase.getExpiresAt(), snapshot.expiresAt())
      || !Objects.equals(purchase.getGracePeriodExpiresAt(), snapshot.gracePeriodExpiresAt())
      || !Objects.equals(purchase.getWillAutoRenew(), snapshot.willAutoRenew())
      || !Objects.equals(purchase.getRevokedAt(), snapshot.revokedAt())
      || !Objects.equals(purchase.getLatestTransactionId(), snapshot.latestTransactionId())
      || !Objects.equals(purchase.getLinkedPurchaseKey(), snapshot.linkedPurchaseKey());
    purchase.setProductId(snapshot.productId());
    purchase.setEnvironment(snapshot.environment());
    purchase.setState(snapshot.state());
    purchase.setExpiresAt(snapshot.expiresAt());
    purchase.setGracePeriodExpiresAt(snapshot.gracePeriodExpiresAt());
    purchase.setWillAutoRenew(snapshot.willAutoRenew());
    purchase.setRevokedAt(snapshot.revokedAt());
    purchase.setLatestTransactionId(snapshot.latestTransactionId());
    purchase.setLinkedPurchaseKey(snapshot.linkedPurchaseKey());
    if (snapshot.storeSignedAt() != null) {
      purchase.setStoreSignedAt(snapshot.storeSignedAt());
    }
    // 확인 완료는 되돌리지 않음 (Google 이 확인 전 상태를 늦게 돌려줘도). 새 구매는 스토어 값 그대로
    purchase.setAcknowledged((purchase.getId() != null && purchase.isAcknowledged()) || !snapshot.needsAcknowledge());
    return isChanged;
  }
}
