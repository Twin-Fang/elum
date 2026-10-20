package com.chuseok22.elumserver.notification.core;

import java.time.ZoneId;

/**
 * 알림 시간대 단일 원본: 스케줄 zone 속성(문자열)과 Clock 용 ZoneId
 */
public final class NotificationTime {

  // 알림 기준 시간대 (@Scheduled zone 속성은 상수 문자열이 필요)
  public static final String ZONE_ID_NAME = "Asia/Seoul";
  public static final ZoneId ZONE_ID = ZoneId.of(ZONE_ID_NAME);

  private NotificationTime() {
  }
}
