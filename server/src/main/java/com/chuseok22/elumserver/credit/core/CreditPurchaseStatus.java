package com.chuseok22.elumserver.credit.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

/// 크레딧 구매 기록의 상태 (저장된 이름이라 바꾸지 않는다)
@Getter
@AllArgsConstructor
public enum CreditPurchaseStatus {
  /// 적립됨
  GRANTED("적립"),
  /// 회수됨: 스토어 환불 알림 · 환불 재확인 · 관리자 회수 (남은 양을 회수한 뒤, 계기는 refund_origin)
  REFUNDED("환불"),
  ;

  private final String label;
}
