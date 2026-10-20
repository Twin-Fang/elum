package com.chuseok22.elumserver.notification.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/** 보호자의 푸시 설정: 푸시 여부만 정한다(알림 목록은 항상 쌓임). 행이 없으면 모두 켜짐 */
@Entity
@Getter
@Setter
@Table(name = "notification_setting")
public class NotificationSetting extends BaseEntity {

  @Id
  @Column(name = "member_id")
  private String memberId;

  // 전체 끔이면 종류별 값과 무관하게 푸시 없음
  @Column(name = "all_enabled", nullable = false, columnDefinition = "boolean not null default true")
  private boolean isAllEnabled = true;

  @Column(name = "routine_completed_enabled", nullable = false, columnDefinition = "boolean not null default true")
  private boolean isRoutineCompletedEnabled = true;

  @Column(name = "routine_sent_enabled", nullable = false, columnDefinition = "boolean not null default true")
  private boolean isRoutineSentEnabled = true;

  @Column(name = "co_guardian_joined_enabled", nullable = false, columnDefinition = "boolean not null default true")
  private boolean isCoGuardianJoinedEnabled = true;

  @Column(name = "credit_refilled_enabled", nullable = false, columnDefinition = "boolean not null default true")
  private boolean isCreditRefilledEnabled = true;

  @Column(name = "feedback_resolved_enabled", nullable = false, columnDefinition = "boolean not null default true")
  private boolean isFeedbackResolvedEnabled = true;
}
