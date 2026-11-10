package com.chuseok22.elumserver.license.application.service.store;

import com.chuseok22.elumserver.license.core.SubscriptionSource;

/**
 * 소모성 상품(크레딧 꾸러미) 환불 알림을 받는 쪽. 스토어 알림 수신·서명 검증은 license 가 하고, 회수는 구현체가 한다
 * 거래 id 는 Apple transactionId · Google orderId
 */
public interface StoreConsumableRefundHandler {

  /// 그 거래로 준 적립의 남은 양을 회수한다. 모르는 거래·이미 환불된 거래는 아무것도 하지 않는다
  void refund(SubscriptionSource store, String transactionId);
}
