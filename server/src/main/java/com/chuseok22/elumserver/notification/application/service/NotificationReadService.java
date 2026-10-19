package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.notification.infrastructure.entity.Notification;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationRepository;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneId;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/// 알림 읽음 처리: 한 건(내 것만), 전체(내 안 읽은 것만)
@Service
@Transactional
public class NotificationReadService {

  private static final ZoneId NOTIFICATION_ZONE = ZoneId.of("Asia/Seoul");

  private final NotificationRepository notificationRepository;
  private final Clock clock;

  @Autowired
  public NotificationReadService(NotificationRepository notificationRepository) {
    this(notificationRepository, Clock.system(NOTIFICATION_ZONE));
  }

  NotificationReadService(NotificationRepository notificationRepository, Clock clock) {
    this.notificationRepository = notificationRepository;
    this.clock = clock;
  }

  /// 한 건 읽음: 없거나 남의 알림이면 같은 404 (존재 여부를 흘리지 않음), 이미 읽었으면 그대로
  public void markRead(String memberId, String notificationId) {
    Notification notification = notificationRepository.findById(notificationId)
      .filter(row -> memberId.equals(row.getRecipientMemberId()))
      .orElseThrow(() -> new CustomException(ErrorCode.NOTIFICATION_NOT_FOUND));
    if (notification.getReadAt() == null) {
      notification.setReadAt(LocalDateTime.now(clock));
    }
  }

  /// 전체 읽음: 내 안 읽은 알림만 한 번에
  public void markAllRead(String memberId) {
    notificationRepository.markAllRead(memberId, LocalDateTime.now(clock));
  }
}
