package com.chuseok22.elumserver.adreward.infrastructure.entity;

import com.chuseok22.elumserver.adreward.core.AdRewardRejectReason;
import com.chuseok22.elumserver.adreward.core.AdRewardStatus;
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
import jakarta.persistence.UniqueConstraint;
import java.time.LocalDateTime;
import lombok.Getter;
import lombok.Setter;

/**
 * 광고 한 번을 보고 크레딧을 받는 흐름의 기록 하나.
 *
 * <p>**nonce 가 시청과 회원을 잇는 유일한 끈이다.** 앱이 광고를 요청할 때 이 값을 실으면 Google 이 콜백에 그대로 돌려준다.
 * 콜백은 Google 서명으로 믿을 수 있어도 어느 회원의 시청인지는 앱이 말한 값이라, 서버가 발급하고 한 번만 쓰이는 nonce 로 묶는다.
 *
 * <p>한 번의 시청이 두 번 지급되지 않게 세 겹으로 막는다: 상태 전이(`PENDING → GRANTED` 한 번), `nonce` 유니크,
 * `transaction_id` 유니크.
 *
 * <p>member 에 외래키를 걸지 않는다 — 탈퇴해도 지급 기록은 남는다(크레딧 원장과 같은 이유).
 */
@Entity
@Getter
@Setter
@Table(
  name = "ad_reward_session",
  uniqueConstraints = {
    @UniqueConstraint(name = "uk_ad_reward_session_nonce", columnNames = "nonce"),
    @UniqueConstraint(name = "uk_ad_reward_session_tx", columnNames = "transaction_id")
  },
  indexes = {
    @Index(name = "idx_ad_reward_session_member_status", columnList = "member_id, status, expires_at")
  }
)
public class AdRewardSession extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(name = "member_id", nullable = false)
  private String memberId;

  @Column(nullable = false, length = 64)
  private String nonce;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private AdRewardStatus status = AdRewardStatus.PENDING;

  @Column(name = "expires_at", nullable = false)
  private LocalDateTime expiresAt;

  @Column(name = "granted_at")
  private LocalDateTime grantedAt;

  @Column(name = "granted_credits", nullable = false)
  private int grantedCredits;

  @Enumerated(EnumType.STRING)
  @Column(name = "reject_reason", length = 30)
  private AdRewardRejectReason rejectReason;

  /// Google 이 시청 한 번마다 붙이는 ID. 지급된 뒤에만 채운다(null 은 여러 행 허용).
  @Column(name = "transaction_id")
  private String transactionId;

  /// 지급으로 만든 적립 묶음.
  @Column(name = "grant_id")
  private String grantId;

  public boolean isExpiredAt(LocalDateTime now) {
    return !now.isBefore(expiresAt);
  }
}
