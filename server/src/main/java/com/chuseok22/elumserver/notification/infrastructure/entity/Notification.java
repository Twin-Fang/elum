package com.chuseok22.elumserver.notification.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.notification.core.NotificationType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.LocalDateTime;
import lombok.Getter;
import lombok.Setter;

/**
 * 보호자 알림 목록의 한 줄: 같은 묶음(groupKey)의 발생을 한 줄에 모은다
 *
 * <p>member 에 외래키를 걸지 않는다. 입력 원문(일과 제목 등)은 복사하지 않고 id 만 담는다.
 */
@Entity
@Getter
@Setter
@Table(
  name = "notification",
  uniqueConstraints = @UniqueConstraint(name = "uk_notification_member_group", columnNames = {"member_id", "group_key"}),
  indexes = {
    @Index(name = "idx_notification_member_last_occurred", columnList = "member_id, last_occurred_at"),
    @Index(name = "idx_notification_profile_id", columnList = "profile_id")
  }
)
public class Notification extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  // 받는 보호자
  @Column(name = "member_id", nullable = false)
  private String recipientMemberId;

  // 이룸이 프로필. 프로필과 무관한 알림(크레딧 등)은 null
  @Column(name = "profile_id")
  private String profileId;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 40)
  private NotificationType type;

  // 눌렀을 때 갈 대상 id (일과 id 등). 없으면 null
  @Column(name = "target_id")
  private String targetId;

  // 묶음 키: 같은 (받는 사람, 묶음 키)는 한 줄로 모인다
  @Column(name = "group_key", nullable = false)
  private String groupKey;

  // 일과 완료의 일과 id 목록 (쉼표 구분)
  @Column(name = "subject_ids", columnDefinition = "TEXT")
  private String subjectIds;

  // 이 줄에 모인 발생 횟수
  @Column(name = "occurrence_count", nullable = false)
  private int count = 1;

  @Column(name = "last_occurred_at", nullable = false)
  private LocalDateTime lastOccurredAt;

  // 읽은 시각. 안 읽었으면 null
  @Column(name = "read_at")
  private LocalDateTime readAt;
}
