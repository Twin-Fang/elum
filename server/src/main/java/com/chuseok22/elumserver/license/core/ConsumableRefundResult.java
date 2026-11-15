package com.chuseok22.elumserver.license.core;

/**
 * 소모성 상품(크레딧 꾸러미) 환불·환불 취소 1건의 처리 결과
 */
public enum ConsumableRefundResult {
  /// 남은 양을 회수하고 환불로 표시함
  REVOKED,
  /// 이미 환불로 표시된 거래 (같은 환불이 다시 옴)
  ALREADY_REFUNDED,
  /// 모르는 거래라 보류해 둠 (구매 확인 때 바로 회수)
  HELD,
  /// 모르는 거래, 보류하지 않음 (재확인·관리자 경로)
  UNKNOWN,
  /// 환불 취소: 회수분을 다시 적립함
  REVERSED,
  /// 환불 취소: 보류 중이던 환불을 풀어 줌
  HOLD_RELEASED,
  /// 환불 취소인데 환불된 적 없는 거래
  NOT_REFUNDED,
  ;

  /// 거래 이력 결과로: 바뀜 > 반영, 이미 같음 > 변화 없음, 보류·모름 > 회원 미연결
  public StorePurchaseEventResult toEventResult() {
    return switch (this) {
      case REVOKED, REVERSED, HOLD_RELEASED -> StorePurchaseEventResult.APPLIED;
      case ALREADY_REFUNDED, NOT_REFUNDED -> StorePurchaseEventResult.UNCHANGED;
      case HELD, UNKNOWN -> StorePurchaseEventResult.UNBOUND;
    };
  }
}
