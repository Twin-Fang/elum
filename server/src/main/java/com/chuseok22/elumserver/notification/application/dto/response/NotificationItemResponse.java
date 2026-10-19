package com.chuseok22.elumserver.notification.application.dto.response;

import com.chuseok22.elumserver.notification.core.NotificationType;
import java.time.LocalDateTime;

/// 알림 목록 한 줄. profileName·routineTitle 은 지금 값이며, 지워졌거나 접근할 수 없으면 null
public record NotificationItemResponse(
  String id,
  NotificationType type,
  String profileId,
  String profileName,
  String targetId,
  String routineTitle,
  int count,
  LocalDateTime occurredAt,
  boolean isRead
) {

}
