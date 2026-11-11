package com.chuseok22.elumserver.credit.core;

/// 구매 확인 응답의 status. 앱이 그대로 읽는다.
public enum CreditPurchaseResultStatus {
  /// 이번 요청으로 적립함
  GRANTED,
  /// 이미 적립된 거래 (재시도·복원)
  ALREADY_GRANTED,
  /// 스토어 결제가 아직 끝나지 않았거나 스토어 확인이 늦음. 적립하지 않았고 나중에 다시 확인
  PENDING,
}
