package com.chuseok22.elumserver.adreward.core;

/// 광고 보상 세션의 상태 (#463). `PENDING` 만 지급할 수 있고, 나머지는 끝난 상태다.
public enum AdRewardStatus {
  /// 세션을 만들었고 Google 콜백을 기다린다.
  PENDING,
  /// 콜백을 확인해 크레딧을 줬다. 한 번뿐이다.
  GRANTED,
  /// 콜백은 맞았지만 규칙에 걸려 주지 않았다(사유는 rejectReason).
  REJECTED,
  /// 유효 시간 안에 콜백이 오지 않았다.
  EXPIRED,
}
