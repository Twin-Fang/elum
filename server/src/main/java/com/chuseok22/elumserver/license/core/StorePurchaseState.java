package com.chuseok22.elumserver.license.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 스토어 구독 1건의 상태 (App Store·Google Play 공통으로 맞춘 값)
 * Pro 를 주는 상태 2개: ACTIVE, IN_GRACE_PERIOD. 그 외는 만료일과 관계없이 Pro 아님
 */
@Getter
@AllArgsConstructor
public enum StorePurchaseState {

  ACTIVE("이용 중", true),
  /// 결제 실패 후 스토어가 주는 유예 기간 (이용은 계속)
  IN_GRACE_PERIOD("결제 유예", true),
  /// 결제 재시도 중, 유예 없음 (Apple billing retry, Google ON_HOLD)
  BILLING_RETRY("결제 재시도", false),
  PAUSED("일시 정지", false),
  /// 결제 대기 (Google 지연 결제)
  PENDING("결제 대기", false),
  EXPIRED("만료", false),
  /// 환불·취소로 회수
  REVOKED("환불·회수", false),
  ;

  private final String label;
  private final boolean isEntitledState;
}
