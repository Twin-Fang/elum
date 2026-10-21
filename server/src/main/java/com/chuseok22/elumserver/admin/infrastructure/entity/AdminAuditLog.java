package com.chuseok22.elumserver.admin.infrastructure.entity;

import com.chuseok22.elumserver.admin.core.AdminAuditAction;
import com.chuseok22.elumserver.admin.core.AdminAuditTargetType;
import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/**
 * 관리자 동작 기록 1줄 (#653): 누가, 무엇을, 어느 대상에, 언제. 추가만 하고 고치거나 지우지 않음
 * detail 은 짧은 요약만 (메모·사유·프롬프트 원문, 비밀번호·토큰 금지). 회원 FK 없음: 완전 삭제 뒤에도 기록은 남음
 */
@Entity
@Getter
@Setter
@Table(name = "admin_audit_log", indexes = {
  @Index(name = "idx_admin_audit_log_created_at", columnList = "created_at"),
  @Index(name = "idx_admin_audit_log_target", columnList = "target_type, target_id"),
  @Index(name = "idx_admin_audit_log_admin_username", columnList = "admin_username")})
public class AdminAuditLog extends BaseEntity {

  /// detail 최대 길이 (V56 컬럼과 같음)
  public static final int MAX_DETAIL_LENGTH = 500;
  /// target_id 최대 길이 (V56 컬럼과 같음)
  public static final int MAX_TARGET_ID_LENGTH = 255;

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  // 세션 로그인 이름, 못 얻으면 unknown
  @Column(name = "admin_username", nullable = false)
  private String adminUsername;

  @Enumerated(EnumType.STRING)
  @Column(name = "action", nullable = false, length = 50)
  private AdminAuditAction action;

  @Enumerated(EnumType.STRING)
  @Column(name = "target_type", nullable = false, length = 30)
  private AdminAuditTargetType targetType;

  @Column(name = "target_id", length = MAX_TARGET_ID_LENGTH)
  private String targetId;

  @Column(name = "detail", length = MAX_DETAIL_LENGTH)
  private String detail;

  // 요청 id (MDC requestId, 서버 로그·X-Request-Id 와 같은 값). 없으면 null
  @Column(name = "request_id", length = 64)
  private String requestId;
}
