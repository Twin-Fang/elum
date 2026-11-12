package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.notification.core.AutoNotificationType;
import com.chuseok22.elumserver.notification.core.NotificationDispatchSource;

/**
 * 운영자 알림을 보낸 곳 (#1275): 발송 기록 출처 + 자동 알림 종류(자동만)
 */
public record AdminMessageOrigin(NotificationDispatchSource source, AutoNotificationType autoType) {

  public static AdminMessageOrigin adminManual() {
    return new AdminMessageOrigin(NotificationDispatchSource.ADMIN_MANUAL, null);
  }

  public static AdminMessageOrigin adminScheduled() {
    return new AdminMessageOrigin(NotificationDispatchSource.ADMIN_SCHEDULED, null);
  }

  public static AdminMessageOrigin autoRule(AutoNotificationType type) {
    return new AdminMessageOrigin(NotificationDispatchSource.AUTO_RULE, type);
  }
}
