package com.chuseok22.elumserver.notification.application.dto.response;

/// 안 읽음 요약: 알림 안 읽음 여부·개수, 안 읽은 공지 여부
public record UnreadSummaryResponse(
  boolean hasUnreadNotification,
  long unreadNotificationCount,
  boolean hasUnreadNotice
) {

}
