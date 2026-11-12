package com.chuseok22.elumserver.notification.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.notification.core.AutoNotificationType;
import com.chuseok22.elumserver.notification.core.NotificationDispatchSource;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import java.time.LocalDateTime;
import lombok.Getter;
import lombok.Setter;

/**
 * 받는 사람 한 명에게 간 운영자·자동 알림 한 번 (#1275): 출처, 자동 종류, 기기 결과, 열린 시각
 * 푸시 data 의 dispatchId = 이 id > 앱이 눌러 열면 opened_at 기록 (알림 성과 화면의 원천)
 */
@Entity
@Getter
@Setter
@Table(name = "notification_dispatch", indexes = {
  @Index(name = "idx_notification_dispatch_member_sent", columnList = "member_id, sent_at"),
  @Index(name = "idx_notification_dispatch_sent_at", columnList = "sent_at")
})
public class NotificationDispatch extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(name = "member_id", nullable = false)
  private String memberId;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private NotificationDispatchSource source;

  // 자동 알림 종류 (출처가 AUTO_RULE 일 때만)
  @Enumerated(EnumType.STRING)
  @Column(name = "auto_type", length = 40)
  private AutoNotificationType autoType;

  @Column(name = "admin_message_id")
  private String adminMessageId;

  @Column(name = "sent_at", nullable = false)
  private LocalDateTime sentAt;

  @Column(name = "sent_device_count", nullable = false)
  private int sentDeviceCount;

  @Column(name = "failed_device_count", nullable = false)
  private int failedDeviceCount;

  // 앱이 알린 첫 열림 시각 (두 번째부터는 그대로)
  @Column(name = "opened_at")
  private LocalDateTime openedAt;
}
