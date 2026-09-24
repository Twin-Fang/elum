package com.chuseok22.elumserver.credit.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.credit.core.CreditGrantSource;
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
 * 적립 묶음 하나 (#407). 주간 지급·관리자 보너스가 각각 한 행이다.
 *
 * <p>묶음을 나눠 두는 이유는 만료가 다르기 때문이다 — 차감은 만료 임박 묶음부터(무기한은 마지막) 해서
 * 곧 사라질 크레딧을 먼저 쓴다. 잔액 한 숫자로 두면 무엇이 언제 사라지는지 알 수 없다.
 */
@Entity
@Getter
@Setter
@Table(
  name = "ai_credit_grant",
  uniqueConstraints = @UniqueConstraint(name = "uk_ai_credit_grant_period", columnNames = {"account_id", "period_key"}),
  indexes = @Index(name = "idx_ai_credit_grant_account_created", columnList = "account_id, created_at")
)
public class AiCreditGrant extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(name = "account_id", nullable = false)
  private String accountId;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 30)
  private CreditGrantSource source;

  @Column(nullable = false)
  private int amount;

  @Column(nullable = false)
  private int remaining;

  @Column(name = "valid_from", nullable = false)
  private LocalDateTime validFrom;

  /// null 이면 무기한.
  @Column(name = "expires_at")
  private LocalDateTime expiresAt;

  /// 주간 지급만 채운다(ISO 주, 2026-W39). (account_id, period_key) 유니크가 같은 주 두 번 지급을 막는다.
  @Column(name = "period_key", length = 10)
  private String periodKey;

  @Column(name = "policy_version")
  private Integer policyVersion;

  /// 관리자 조정·결제 등 이 지급을 만든 근거의 식별자.
  @Column(name = "ref_id")
  private String refId;

  /// valid_from ≤ now < expires_at(무기한이면 끝 없음).
  public boolean isValidAt(LocalDateTime now) {
    return !now.isBefore(validFrom) && (expiresAt == null || now.isBefore(expiresAt));
  }
}
