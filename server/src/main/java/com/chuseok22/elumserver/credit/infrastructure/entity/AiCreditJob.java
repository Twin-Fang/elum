package com.chuseok22.elumserver.credit.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.credit.core.CreditJobStatus;
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
 * 크레딧을 쓰는 생성 작업 한 건 (#407). 멱등 키이자 예약 자리다.
 *
 * <p>(account_id, request_key) 유니크로 같은 요청을 두 번 청구하지 않는다. 실패로 반환된 키가 다시 오면
 * (앱의 "다시 하기"는 같은 키를 쓴다) 이 행을 다시 예약 상태로 되돌려 쓴다.
 *
 * <p>cost_snapshot 은 시작 시점 정책의 단가 JSON 이다 — 진행 중에 정책이 바뀌어도 이 작업은 시작 때 단가로 정산한다.
 */
@Entity
@Getter
@Setter
@Table(
  name = "ai_credit_job",
  uniqueConstraints = @UniqueConstraint(name = "uk_ai_credit_job_request", columnNames = {"account_id", "request_key"}),
  indexes = {
    @Index(name = "idx_ai_credit_job_account_created", columnList = "account_id, created_at"),
    @Index(name = "idx_ai_credit_job_status_started", columnList = "status, started_at")
  }
)
public class AiCreditJob extends BaseEntity {

  private static final int FAIL_REASON_MAX_LENGTH = 500;

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(name = "account_id", nullable = false)
  private String accountId;

  @Column(name = "request_key", nullable = false)
  private String requestKey;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 30)
  private CreditJobKind kind;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private CreditJobStatus status;

  /// 예약량. RESERVED 동안 사용 가능량에서 빠진다.
  @Column(nullable = false)
  private int reserved;

  /// 실제 차감량 = min(청구, 사용 가능 + 예약).
  @Column(nullable = false)
  private int charged;

  /// 청구했지만 잔액이 모자라 차감하지 못한 몫.
  @Column(nullable = false)
  private int overage;

  @Column(name = "image_count", nullable = false)
  private int imageCount;

  @Column(name = "card_count", nullable = false)
  private int cardCount;

  @Column(name = "policy_version")
  private Integer policyVersion;

  @Column(name = "cost_snapshot", columnDefinition = "TEXT")
  private String costSnapshot;

  @Column(name = "routine_id")
  private String routineId;

  @Column(name = "step_id")
  private String stepId;

  @Column(name = "started_at", nullable = false)
  private LocalDateTime startedAt;

  @Column(name = "finished_at")
  private LocalDateTime finishedAt;

  @Column(name = "fail_reason", length = FAIL_REASON_MAX_LENGTH)
  private String failReason;

  /// 사유가 길어도 저장이 실패하지 않게 자른다 — 반환이 실패하면 예약이 TTL 까지 묶인다.
  public void setFailReason(String failReason) {
    this.failReason = (failReason != null && failReason.length() > FAIL_REASON_MAX_LENGTH)
      ? failReason.substring(0, FAIL_REASON_MAX_LENGTH)
      : failReason;
  }
}
