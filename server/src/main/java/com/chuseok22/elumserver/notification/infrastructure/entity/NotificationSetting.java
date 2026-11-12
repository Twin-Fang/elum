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

  // 이야기: 내 글에 댓글이 달렸을 때
  @Column(name = "talk_commented_enabled", nullable = false, columnDefinition = "boolean not null default true")
  private boolean isTalkCommentedEnabled = true;

  // 이야기: 내 글을 누가 일과관리로 가져갔을 때
  @Column(name = "talk_imported_enabled", nullable = false, columnDefinition = "boolean not null default true")
  private boolean isTalkImportedEnabled = true;

  // 자동 알림 (#1275): 오늘 일과 보내기
  @Column(name = "routine_nudge_enabled", nullable = false, columnDefinition = "boolean not null default true")
  private boolean isRoutineNudgeEnabled = true;

  // 자동 알림 (#1275): 추천 (다시 찾기, 이야기 인기 일과)
  @Column(name = "suggestion_enabled", nullable = false, columnDefinition = "boolean not null default true")
  private boolean isSuggestionEnabled = true;

  // 자동 알림 (#1275): 요금제 안내 (Pro 선물·체험 끝나기 전)
  @Column(name = "plan_reminder_enabled", nullable = false, columnDefinition = "boolean not null default true")
  private boolean isPlanReminderEnabled = true;
}
