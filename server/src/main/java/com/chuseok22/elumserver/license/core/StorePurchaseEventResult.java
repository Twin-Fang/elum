package com.chuseok22.elumserver.license.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 검증 요청·알림 1건의 처리 결과
 */
@Getter
@AllArgsConstructor
public enum StorePurchaseEventResult {

  /// 구매 상태나 회원 연결이 바뀜
  APPLIED("반영"),
  /// 이미 같은 상태 (같은 거래를 다시 보냄)
  UNCHANGED("변화 없음"),
  /// 이미 받은 것보다 오래된 상태라 덮지 않음
  STALE("오래된 정보"),
  /// 묶을 회원을 몰라 상태만 저장 (앱 검증 요청이 오면 묶음)
  UNBOUND("회원 미연결"),
  /// 다른 회원에 묶인 구매 등으로 거부
  REJECTED("거부"),
  ;

  private final String label;
}
