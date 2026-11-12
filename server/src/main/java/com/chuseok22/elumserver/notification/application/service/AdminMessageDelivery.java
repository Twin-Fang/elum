package com.chuseok22.elumserver.notification.application.service;

import java.util.HashMap;
import java.util.Map;

/**
 * 운영자 알림 기기 발송 결과: 성공 기기 수, 실패 기기 수(무효 토큰·발송 실패·예외), 받는 사람별 기기 결과(발송 기록용)
 * 전체 끔·종류 끔·기기 없음은 발송 대상이 아니라 어느 쪽에도 세지 않음
 */
public record AdminMessageDelivery(int sentDeviceCount, int failedDeviceCount,
  Map<String, MemberDeviceCount> deviceCountByMemberId) {

  public AdminMessageDelivery(int sentDeviceCount, int failedDeviceCount) {
    this(sentDeviceCount, failedDeviceCount, Map.of());
  }

  /// 받는 사람 한 명의 기기 결과
  public record MemberDeviceCount(int sentDeviceCount, int failedDeviceCount) {
  }

  /// 발송 중 결과 세기 (한 번의 발송 안에서만 씀)
  static final class Counter {

    private int sentDeviceCount;
    private int failedDeviceCount;
    private final Map<String, int[]> sentAndFailedByMemberId = new HashMap<>();

    void addSentDevice(String memberId) {
      sentDeviceCount++;
      countsOf(memberId)[0]++;
    }

    void addFailedDevice(String memberId) {
      failedDeviceCount++;
      countsOf(memberId)[1]++;
    }

    private int[] countsOf(String memberId) {
      return sentAndFailedByMemberId.computeIfAbsent(memberId, ignored -> new int[2]);
    }

    AdminMessageDelivery toDelivery() {
      Map<String, MemberDeviceCount> deviceCountByMemberId = new HashMap<>();
      sentAndFailedByMemberId.forEach((memberId, counts) ->
        deviceCountByMemberId.put(memberId, new MemberDeviceCount(counts[0], counts[1])));
      return new AdminMessageDelivery(sentDeviceCount, failedDeviceCount, Map.copyOf(deviceCountByMemberId));
    }
  }
}
