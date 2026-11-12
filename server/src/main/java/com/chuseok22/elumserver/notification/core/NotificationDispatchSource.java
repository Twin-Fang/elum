package com.chuseok22.elumserver.notification.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 발송 기록 출처 3개 (#1275): 자동 알림 규칙, 운영자 직접 보내기, 예약 발송
 * 하루 1개 상한은 AUTO_RULE 만 셈 (운영자 발송 제외)
 */
@Getter
@AllArgsConstructor
public enum NotificationDispatchSource {

  AUTO_RULE("자동 알림"),
  ADMIN_MANUAL("운영자 직접"),
  ADMIN_SCHEDULED("예약 발송"),
  ;

  private final String label;
}
