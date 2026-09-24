package com.chuseok22.elumserver.credit.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.credit.core.CreditAccountStatus;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.Getter;
import lombok.Setter;

/**
 * 회원 한 명의 크레딧 계정 (#407). <b>모든 증감은 이 행을 {@code FOR UPDATE} 로 잡은 안에서 일어난다</b> —
 * 서버가 여러 대여도 같은 회원의 예약·정산이 한 줄로 선다.
 *
 * <p>member_id 는 완전 삭제(purge) 때 떼어낸다. 행과 원장은 남기고, 같은 소셜 신원(identity_key)으로
 * 다시 가입하면 새 회원에 다시 붙여 이번 주 사용량을 잇는다 — 탈퇴·재가입으로 주간 지급을 새로 받지 못하게.
 * member 에 외래키를 걸지 않는다 — 가입 트랜잭션 밖(REQUIRES_NEW)에서 계정을 만들 수 있어야 한다.
 */
@Entity
@Getter
@Setter
@Table(
  name = "ai_credit_account",
  uniqueConstraints = {
    @UniqueConstraint(name = "uk_ai_credit_account_member", columnNames = "member_id"),
    @UniqueConstraint(name = "uk_ai_credit_account_identity", columnNames = "identity_key")
  }
)
public class AiCreditAccount extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  /// 완전 삭제 뒤에는 null 이다.
  @Column(name = "member_id")
  private String memberId;

  /// sha256("{provider}:{providerUserId}") hex. 신원을 모르는 채 만든 계정은 null 이다.
  @Column(name = "identity_key", length = 64)
  private String identityKey;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private CreditAccountStatus status = CreditAccountStatus.ACTIVE;

  public boolean isFrozen() {
    return status == CreditAccountStatus.FROZEN;
  }
}
