package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.notification.core.AutoNotificationType;
import java.util.Map;

/**
 * 운영자 알림 푸시에 더할 것 (#1275): 받는 사람별 발송 기록 id(푸시 data dispatchId), 자동 알림 종류(종류별 끄기 확인)
 * autoType 이 null 이면 전체 끔만 따름 (운영자 직접·예약)
 */
public record AdminMessagePushContext(Map<String, String> dispatchIdByMemberId, AutoNotificationType autoType) {

  public static AdminMessagePushContext none() {
    return new AdminMessagePushContext(Map.of(), null);
  }

  String dispatchIdOf(String memberId) {
    return dispatchIdByMemberId == null ? null : dispatchIdByMemberId.get(memberId);
  }
}
