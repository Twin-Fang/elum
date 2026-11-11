package com.chuseok22.elumserver.notification.application.service;

/// 이룸이 기기 푸시 한 번의 결과: 대상 기기 수 · 실제로 보낸 수 (무효 토큰·실패는 보낸 수에서 빠짐)
public record ElumiPushResult(int deviceCount, int sentCount) {

  /// 살아 있는 연결이 없어 대상 기기 0대
  public static final ElumiPushResult NO_DEVICE = new ElumiPushResult(0, 0);
}
