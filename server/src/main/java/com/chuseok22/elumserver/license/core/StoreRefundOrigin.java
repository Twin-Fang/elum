package com.chuseok22.elumserver.license.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 환불 회수 계기 3개: 스토어 알림, 매일 환불 재확인, 관리자 수동 회수 (저장된 이름이라 바꾸지 않는다)
 */
@Getter
@AllArgsConstructor
public enum StoreRefundOrigin {

  STORE_NOTIFICATION("스토어 알림"),
  REFUND_RECHECK("환불 재확인"),
  ADMIN("관리자 회수"),
  ;

  private final String label;
}
