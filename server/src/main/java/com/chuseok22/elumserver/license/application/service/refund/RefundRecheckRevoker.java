package com.chuseok22.elumserver.license.application.service.refund;

import com.chuseok22.elumserver.license.application.service.store.StoreConsumableRefundHandler;
import com.chuseok22.elumserver.license.application.service.store.StoreConsumableRefundHandler.ConsumableRefundOutcome;
import com.chuseok22.elumserver.license.application.service.store.StorePurchaseApplier;
import com.chuseok22.elumserver.license.core.StorePurchaseEventResult;
import com.chuseok22.elumserver.license.core.StorePurchaseTrigger;
import com.chuseok22.elumserver.license.core.StoreRefundOrigin;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * 환불 재확인이 찾은 환불 1건 회수 2종: 구독(Pro) · 크레딧 꾸러미. 건마다 따로 트랜잭션 (한 건 실패가 나머지를 막지 않음)
 * 이미 회수했거나 모르는 구매는 아무것도 바꾸지 않고 이력도 남기지 않음 (매일 같은 목록을 받아도 쌓이지 않게)
 */
@Component
@RequiredArgsConstructor
public class RefundRecheckRevoker {

  private final StorePurchaseApplier applier;
  private final StoreConsumableRefundHandler consumableRefundHandler;

  /// 구독 회수 > 회원 Pro 다시 계산. 이번에 회수했으면 true
  public boolean revokeSubscription(SubscriptionSource store, String purchaseKey, String eventType) {
    return applier.revokeIfNotRevoked(store, purchaseKey, eventType);
  }

  /// 크레딧 꾸러미 남은 양 회수 > 거래 이력 1줄. 이번에 회수했으면 true
  public boolean revokeConsumable(SubscriptionSource store, String transactionId, String eventType) {
    ConsumableRefundOutcome outcome = consumableRefundHandler.refund(store, transactionId, StoreRefundOrigin.REFUND_RECHECK);
    if (!outcome.isRevoked()) {
      return false;
    }
    applier.recordConsumableEvent(store, transactionId, outcome.memberId(), StorePurchaseTrigger.REFUND_RECHECK, eventType,
      null, StorePurchaseEventResult.APPLIED, outcome.result().name());
    return true;
  }
}
