package com.chuseok22.elumserver.notification.core;

import java.time.LocalDateTime;
import java.time.LocalTime;

/**
 * 알림 야간 금지 시간 단일 원본: [21:00, 다음 날 08:00) 한국 시각
 * 운영자 보내기·예약 발송·자동 알림이 같은 기준을 씀 (운영자 먼저 보내 보기는 예외)
 */
public final class NotificationQuietHours {

  public static final LocalTime START = LocalTime.of(21, 0);
  public static final LocalTime END = LocalTime.of(8, 0);

  private NotificationQuietHours() {
  }

  /// 그 시각(KST)이 야간 금지 시간 안인지
  public static boolean isQuietTime(LocalTime time) {
    return !time.isBefore(START) || time.isBefore(END);
  }

  public static boolean isQuietTime(LocalDateTime dateTime) {
    return isQuietTime(dateTime.toLocalTime());
  }
}
