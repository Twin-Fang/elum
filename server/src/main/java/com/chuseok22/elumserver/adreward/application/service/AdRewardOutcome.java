package com.chuseok22.elumserver.adreward.application.service;

/// 서명이 확인된 콜백을 처리한 결과.
public enum AdRewardOutcome {
  /// 이번 콜백으로 크레딧을 줬다.
  GRANTED,
  /// 이미 준 시청이다. 다시 주지 않았다(재시도에 대한 정상 응답).
  DUPLICATE,
  /// 규칙에 걸려 주지 않았다.
  REJECTED,
  /// 우리 세션이 아니다(알 수 없는 nonce). 아무것도 하지 않았다.
  IGNORED,
}
