package com.chuseok22.elumserver.credit.core;

/// 크레딧 구매 기록의 상태 (저장된 이름이라 바꾸지 않는다)
public enum CreditPurchaseStatus {
  /// 적립됨
  GRANTED,
  /// 스토어가 환불함 (남은 양을 회수한 뒤)
  REFUNDED,
}
