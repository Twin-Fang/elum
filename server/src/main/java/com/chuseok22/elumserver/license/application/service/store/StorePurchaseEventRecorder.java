package com.chuseok22.elumserver.license.application.service.store;

import com.chuseok22.elumserver.license.core.StorePurchaseEventResult;
import com.chuseok22.elumserver.license.core.StorePurchaseTrigger;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.infrastructure.entity.StorePurchase;
import com.chuseok22.elumserver.license.infrastructure.entity.StorePurchaseEvent;
import com.chuseok22.elumserver.license.infrastructure.repository.StorePurchaseEventRepository;
import java.time.LocalDateTime;

/**
 * 스토어 거래 이력 한 줄 쓰기 2종: 구독 상태 반영(앱 검증·알림) · 환불 회수 알림
 * 외부 값(알림 종류·id·거래 id·사유)은 열 길이로 자름. StorePurchaseApplier 가 만들어 씀
 */
class StorePurchaseEventRecorder {

  private static final int TRANSACTION_ID_MAX_LENGTH = 255;

  private final StorePurchaseEventRepository storePurchaseEventRepository;

  StorePurchaseEventRecorder(StorePurchaseEventRepository storePurchaseEventRepository) {
    this.storePurchaseEventRepository = storePurchaseEventRepository;
  }

  void recordEvent(
    StoreSubscriptionSnapshot snapshot, String memberId, StorePurchaseTrigger trigger, String eventType,
    String externalEventId, StorePurchaseEventResult result, String reason, StorePurchase purchase, LocalDateTime now
  ) {
    StorePurchaseEvent event = new StorePurchaseEvent();
    event.setStore(snapshot.store());
    event.setPurchaseKey(snapshot.purchaseKey());
    event.setMemberId(memberId);
    event.setTrigger(trigger);
    event.setEventType(truncate(eventType, StorePurchaseEvent.EVENT_TYPE_MAX_LENGTH));
    event.setExternalEventId(truncate(externalEventId, TRANSACTION_ID_MAX_LENGTH));
    event.setTransactionId(truncate(snapshot.latestTransactionId(), TRANSACTION_ID_MAX_LENGTH));
    event.setResult(result);
    event.setReason(truncate(reason, StorePurchaseEvent.REASON_MAX_LENGTH));
    event.setStateAfter(purchase == null ? null : purchase.getState());
    event.setExpiresAtAfter(purchase == null ? null : purchase.entitledUntil());
    event.setOccurredAt(now);
    storePurchaseEventRepository.save(event);
  }

  void recordRevocationEvent(
    SubscriptionSource store, String purchaseKey, StorePurchase purchase, String eventType, String externalEventId,
    StorePurchaseEventResult result, String memberId, LocalDateTime now
  ) {
    StorePurchaseEvent event = new StorePurchaseEvent();
    event.setStore(store);
    event.setPurchaseKey(purchaseKey);
    event.setMemberId(memberId);
    event.setTrigger(StorePurchaseTrigger.STORE_NOTIFICATION);
    event.setEventType(truncate(eventType, StorePurchaseEvent.EVENT_TYPE_MAX_LENGTH));
    event.setExternalEventId(truncate(externalEventId, TRANSACTION_ID_MAX_LENGTH));
    event.setResult(result);
    event.setStateAfter(purchase == null ? null : purchase.getState());
    event.setOccurredAt(now);
    storePurchaseEventRepository.save(event);
  }

  private static String truncate(String value, int maxLength) {
    return value == null || value.length() <= maxLength ? value : value.substring(0, maxLength);
  }
}
