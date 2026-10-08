package com.chuseok22.elumserver.adreward.core;

/// 서명이 맞는 콜백을 왜 지급하지 않았나. 세션에 남겨 "왜 안 들어왔나"를 나중에 대조한다.
public enum AdRewardRejectReason {
  /// 기능이 꺼져 있다(관리자가 껐다).
  DISABLED,
  /// 우리 보상형 광고 단위가 아니다.
  AD_UNIT,
  /// 이미 끝난 세션이다(이미 지급됐거나 거절됐다).
  NOT_PENDING,
  /// 유효 시간이 지났다.
  EXPIRED,
  /// 계정이 멈춰 있다.
  FROZEN,
  /// 오늘 받을 수 있는 횟수를 다 썼다.
  DAILY_LIMIT,
}
