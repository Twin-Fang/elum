package com.chuseok22.elumserver.admin.application.dto.request;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

/** 관리자 크레딧 조정 종류 (#407). */
@Getter
@RequiredArgsConstructor
public enum CreditAdjustType {

  /// 관리자 보너스 묶음을 새로 준다(만료는 고른다).
  GRANT("지급"),
  /// 남은 양에서 뺀다. 만료 임박 묶음부터, 사용 가능량을 넘을 수 없다.
  DEDUCT("차감"),
  /// 새 예약을 막는다. 잔액은 그대로다.
  FREEZE("동결"),
  UNFREEZE("동결 해제"),
  ;

  private final String label;

  /// 수량을 받는 조정인가. 동결·해제는 수량이 없다.
  public boolean hasAmount() {
    return this == GRANT || this == DEDUCT;
  }
}
