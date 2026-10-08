package com.chuseok22.elumserver.feedback.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/**
 * 보호자가 보낸 의견 하나.
 *
 * <p>member 에 외래키를 걸지 않는다 — 탈퇴해도 관리자가 지울 때까지 남는다.
 */
@Entity
@Getter
@Setter
@Table(
  name = "feedback",
  indexes = @Index(name = "idx_feedback_member_created", columnList = "member_id, created_at")
)
public class Feedback extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(name = "member_id", nullable = false)
  private String memberId;

  @Column(nullable = false, columnDefinition = "TEXT")
  private String message;

  // 앱 상태 기록. 보내지 않으면 null.
  @Column(name = "app_log", columnDefinition = "TEXT")
  private String appLog;

  @Column(name = "app_version", length = 32)
  private String appVersion;

  @Column(length = 64)
  private String os;

  public boolean hasAppLog() {
    return appLog != null && !appLog.isEmpty();
  }
}
