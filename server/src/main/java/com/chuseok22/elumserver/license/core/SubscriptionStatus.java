package com.chuseok22.elumserver.license.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 구독 상태.
 *
 * <p>{@link #ACTIVE}가 아니면 권한 계산에서 Free로 취급한다. 만료는 조회 시점에
 * 만료일과 비교해 판단하므로 상태를 바꿔주는 배치가 필요 없다.
 */
@Getter
@AllArgsConstructor
public enum SubscriptionStatus {

  ACTIVE("이용 중"),
  EXPIRED("기간 만료"),
  CANCELLED("해지"),
  ;

  private final String label;
}
