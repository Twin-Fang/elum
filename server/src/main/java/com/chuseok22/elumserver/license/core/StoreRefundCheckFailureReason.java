package com.chuseok22.elumserver.license.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 환불 재확인 실패 사유 (store_refund_check_run.failure_reason): 원인 종류만, 토큰·응답 원문은 저장하지 않음
 */
@Getter
@AllArgsConstructor
public enum StoreRefundCheckFailureReason {

  STORE_DISABLED("스토어 결제 꺼짐"),
  CREDENTIALS_NOT_CONFIGURED("스토어 API 키 없음"),
  VOIDED_LIST_FAILED("취소 구매 목록 조회 실패"),
  ORDER_LOOKUP_FAILED("주문 상태 조회 실패"),
  TRANSACTION_LOOKUP_FAILED("거래 조회 실패"),
  UNEXPECTED_ERROR("예상하지 못한 오류"),
  ;

  private final String label;
}
