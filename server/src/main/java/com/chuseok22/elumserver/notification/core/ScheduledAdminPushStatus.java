package com.chuseok22.elumserver.notification.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 예약 발송 상태 5개: 기다림 > 보내는 중(한 인스턴스만 선점) > 보냄 / 실패, 기다림 > 취소
 */
@Getter
@AllArgsConstructor
public enum ScheduledAdminPushStatus {

  PENDING("기다림", "info"),
  SENDING("보내는 중", "warning"),
  SENT("보냄", "success"),
  CANCELED("취소", "ghost"),
  FAILED("실패", "error"),
  ;

  private final String label;
  // 관리자 화면 배지 색 (admin-ui toneBadge)
  private final String tone;
}
