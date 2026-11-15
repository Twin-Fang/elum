package com.chuseok22.elumserver.license.application.service.store;

import com.chuseok22.elumserver.license.application.service.store.StoreConsumableRefundHandler.ConsumableRefundOutcome;
import com.chuseok22.elumserver.license.core.StorePurchaseEventResult;
import com.chuseok22.elumserver.license.core.StorePurchaseTrigger;
import com.chuseok22.elumserver.license.core.StoreRefundOrigin;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import lombok.extern.slf4j.Slf4j;

/**
 * 소모성 상품(크레딧 꾸러미) 스토어 알림 3종 반영 + 거래 이력: 환불 > 회수, 환불 취소 > 재적립, 환불 요청 > 기록만
 * 서명·중복 확인은 부르는 쪽(Apple·Google 구독 서비스)이 끝낸 뒤. 이력의 알림 id 가 같은 알림 재처리를 막는다
 */
@Slf4j
class ConsumableNotificationApplier {

  /// App Store 환불 요청 (소비 정보 응답은 하지 않음, 고객 동의 규정)
  static final String CONSUMPTION_REQUEST_EVENT_TYPE = "CONSUMPTION_REQUEST";

  private final StoreConsumableRefundHandler refundHandler;
  private final StorePurchaseApplier applier;

  ConsumableNotificationApplier(StoreConsumableRefundHandler refundHandler, StorePurchaseApplier applier) {
    this.refundHandler = refundHandler;
    this.applier = applier;
  }

  /// 환불 알림: 회수(모르는 거래는 보류) > 이력
  StoreNotificationOutcome applyRefund(SubscriptionSource store, String transactionId, String eventType, String notificationId) {
    ConsumableRefundOutcome outcome = refundHandler.refund(store, transactionId, StoreRefundOrigin.STORE_NOTIFICATION);
    record(store, transactionId, outcome, eventType, notificationId);
    return StoreNotificationOutcome.PROCESSED;
  }

  /// 환불 취소 알림: 회수분 재적립(보류면 풂) > 이력
  StoreNotificationOutcome applyRefundReversed(SubscriptionSource store, String transactionId, String eventType, String notificationId) {
    ConsumableRefundOutcome outcome = refundHandler.reverseRefund(store, transactionId);
    record(store, transactionId, outcome, eventType, notificationId);
    return StoreNotificationOutcome.PROCESSED;
  }

  /// 환불 요청 알림: 관리자가 보도록 기록만
  StoreNotificationOutcome recordConsumptionRequest(SubscriptionSource store, String transactionId, String notificationId) {
    applier.recordConsumableEvent(store, transactionId, null, StorePurchaseTrigger.STORE_NOTIFICATION,
      CONSUMPTION_REQUEST_EVENT_TYPE, notificationId, StorePurchaseEventResult.RECEIVED, null);
    log.info("[subscription notify] consumption request recorded : store={}", store);
    return StoreNotificationOutcome.PROCESSED;
  }

  private void record(
    SubscriptionSource store, String transactionId, ConsumableRefundOutcome outcome, String eventType, String notificationId
  ) {
    applier.recordConsumableEvent(store, transactionId, outcome.memberId(), StorePurchaseTrigger.STORE_NOTIFICATION, eventType,
      notificationId, outcome.result().toEventResult(), outcome.result().name());
    log.info("[subscription notify] consumable applied : store={}, type={}, result={}", store, eventType, outcome.result());
  }
}
