package com.chuseok22.elumserver.credit.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.credit.core.CreditAction;
import com.chuseok22.elumserver.credit.core.CreditLedgerType;
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
 * 추가 전용 원장 (#407). 한 번 쓴 줄은 고치지 않는다 — 잘못된 증감은 ADJUST 로 바로잡는다.
 *
 * <p>delta 는 사용 가능량의 변화, balance_after 는 이 줄을 반영한 뒤의 사용 가능량이다. 호출자가 계산해
 * 넣는다(계정 잠금 안이라 그 사이 다른 증감이 끼지 않는다).
 */
@Entity
@Getter
@Setter
@Table(
  name = "ai_credit_ledger",
  indexes = {
    @Index(name = "idx_ai_credit_ledger_account_created", columnList = "account_id, created_at"),
    @Index(name = "idx_ai_credit_ledger_job", columnList = "job_id")
  }
)
public class AiCreditLedger extends BaseEntity {

  private static final int REASON_MAX_LENGTH = 500;

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(name = "account_id", nullable = false)
  private String accountId;

  @Column(name = "job_id")
  private String jobId;

  @Column(name = "grant_id")
  private String grantId;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private CreditLedgerType type;

  @Column(nullable = false)
  private int delta;

  @Column(name = "balance_after", nullable = false)
  private int balanceAfter;

  @Enumerated(EnumType.STRING)
  @Column(length = 30)
  private CreditAction action;

  @Column(name = "policy_version")
  private Integer policyVersion;

  /// 누가 일으켰나. 시스템이면 "system", 관리자면 로그인 아이디.
  private String actor;

  @Column(length = REASON_MAX_LENGTH)
  private String reason;

  /// 사유가 길어도 원장 저장이 실패하지 않게 자른다 — 원장이 실패하면 반환·정산이 함께 되돌아간다.
  public void setReason(String reason) {
    this.reason = (reason != null && reason.length() > REASON_MAX_LENGTH) ? reason.substring(0, REASON_MAX_LENGTH) : reason;
  }
}
