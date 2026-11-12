package com.chuseok22.elumserver.notification.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.notification.core.AdminMessageRoute;
import com.chuseok22.elumserver.notification.core.ScheduledAdminPushStatus;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import java.time.LocalDate;
import java.time.LocalDateTime;
import lombok.Getter;
import lombok.Setter;

/**
 * 예약 발송 한 건 (#1275): 문구, 받는 사람 조건(#1273 과 같은 방식), 보낼 시각, 상태, 보낸 결과
 * 받는 사람은 보낼 때 다시 계산 (그 사이 정지·탈퇴 회원 제외)
 */
@Entity
@Getter
@Setter
@Table(name = "scheduled_admin_push", indexes = {
  @Index(name = "idx_scheduled_admin_push_status_at", columnList = "status, scheduled_at")
})
public class ScheduledAdminPush extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(nullable = false, length = AdminMessage.TITLE_MAX_LENGTH)
  private String title;

  @Column(nullable = false, length = AdminMessage.BODY_MAX_LENGTH)
  private String body;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private AdminMessageRoute route;

  // MEMBERS 고른 회원, CONDITION 가입일·AI 호출 수
  @Column(name = "target_mode", nullable = false, length = 20)
  private String targetMode;

  // 고른 회원 id 쉼표 목록 (MEMBERS 만)
  @Column(name = "member_ids", columnDefinition = "TEXT")
  private String memberIds;

  @Column(name = "joined_on_or_before")
  private LocalDate joinedOnOrBefore;

  @Column(name = "minimum_ai_call_count")
  private Integer minimumAiCallCount;

  @Column(name = "scheduled_at", nullable = false)
  private LocalDateTime scheduledAt;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private ScheduledAdminPushStatus status;

  @Column(name = "admin_message_id")
  private String adminMessageId;

  @Column(name = "recipient_count")
  private Integer recipientCount;

  @Column(name = "recorded_count")
  private Integer recordedCount;

  @Column(name = "sent_device_count")
  private Integer sentDeviceCount;

  @Column(name = "failed_device_count")
  private Integer failedDeviceCount;

  // 실패·건너뜀 사유 코드 (AdminPushOutcome 이름 등)
  @Column(name = "failure_reason", length = 100)
  private String failureReason;

  @Column(name = "created_by", length = 100)
  private String createdBy;

  @Column(name = "processed_at")
  private LocalDateTime processedAt;
}
