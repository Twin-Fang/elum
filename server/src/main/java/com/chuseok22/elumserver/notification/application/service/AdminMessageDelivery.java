package com.chuseok22.elumserver.notification.application.service;

/**
 * 운영자 알림 기기 발송 결과: 성공 기기 수, 실패 기기 수(무효 토큰·발송 실패·예외)
 * 전체 끔·기기 없음은 발송 대상이 아니라 어느 쪽에도 세지 않음
 */
public record AdminMessageDelivery(int sentDeviceCount, int failedDeviceCount) {

  /// 발송 중 결과 세기 (한 번의 발송 안에서만 씀)
  static final class Counter {

    private int sentDeviceCount;
    private int failedDeviceCount;

    void addSentDevice() {
      sentDeviceCount++;
    }

    void addFailedDevice() {
      failedDeviceCount++;
    }

    AdminMessageDelivery toDelivery() {
      return new AdminMessageDelivery(sentDeviceCount, failedDeviceCount);
    }
  }
}
