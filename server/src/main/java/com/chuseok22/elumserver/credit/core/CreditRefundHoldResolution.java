package com.chuseok22.elumserver.credit.core;

/// 보류한 환불의 끝 (저장된 이름이라 바꾸지 않는다). 대기 중이면 null
public enum CreditRefundHoldResolution {
  /// 구매 확인 때 회수함
  APPLIED,
  /// 구매 확인 전에 환불이 취소됨
  REVERSED,
}
