package com.chuseok22.elumserver.notification.application.dto.response;

import com.chuseok22.elumserver.notification.core.NotificationType;
import java.time.LocalDateTime;

/// 알림 목록 한 줄. profileName·routineTitle 은 지금 값이며, 지워졌거나 접근할 수 없으면 null
/// title·route 는 운영자 알림(ADMIN_MESSAGE)만 값이 있음 (route: home, plan, myCredit)
/// body 는 운영자 알림 본문 또는 의견 처리(FEEDBACK_RESOLVED)의 보낸 의견 본문, feedbackSentAt 은 그 의견을 보낸 시각
public record NotificationItemResponse(
  String id,
  NotificationType type,
  String profileId,
  String profileName,
  String targetId,
  String routineTitle,
  int count,
  LocalDateTime occurredAt,
  boolean isRead,
  String title,
  String body,
  String route,
  LocalDateTime feedbackSentAt
) {

}
