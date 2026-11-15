package com.chuseok22.elumserver.license.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 환불 재확인 실행 방식 2개: 매일 자동, 관리자 "지금 확인" (저장된 이름이라 바꾸지 않는다)
 */
@Getter
@AllArgsConstructor
public enum StoreRefundCheckTrigger {

  SCHEDULED("매일 자동"),
  ADMIN("관리자"),
  ;

  private final String label;
}
