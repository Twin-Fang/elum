package com.chuseok22.elumserver.notification.application.dto.response;

import com.chuseok22.elumserver.notification.core.NotificationType;
import com.chuseok22.elumserver.notification.infrastructure.entity.Notification;
import java.time.LocalDateTime;

/**
 * 관리자 조회용 알림 한 줄: 받는 보호자, 종류, 이룸이·대상 id, 모인 횟수, 처음·마지막 발생, 읽은 시각
 * 묶음 키·일과 id 목록은 담지 않는다
 */
public record NotificationAdminView(
  String id,
  String recipientMemberId,
  NotificationType type,
  String profileId,
  String targetId,
  int occurrenceCount,
  LocalDateTime firstOccurredAt,
  LocalDateTime lastOccurredAt,
  LocalDateTime readAt
) {

  public static NotificationAdminView from(Notification notification) {
    return new NotificationAdminView(
      notification.getId(), notification.getRecipientMemberId(), notification.getType(),
      notification.getProfileId(), notification.getTargetId(), notification.getCount(),
      notification.getCreatedAt(), notification.getLastOccurredAt(), notification.getReadAt());
  }

  public boolean isRead() {
    return readAt != null;
  }
}
