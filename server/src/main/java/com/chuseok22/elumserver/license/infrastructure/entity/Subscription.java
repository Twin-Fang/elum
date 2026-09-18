package com.chuseok22.elumserver.license.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.core.SubscriptionStatus;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import java.time.LocalDateTime;
import lombok.Getter;
import lombok.Setter;

/**
 * 계정 하나의 구독 상태.
 *
 * <p><b>이룸이(Profile)가 아니라 계정(Member)에 붙는다.</b> 돈을 내는 쪽이 보호자이고
 * 당사자는 로그인하지 않기 때문이다. 인앱결제도 Apple ID·Google 계정에 묶이지
 * 프로필에 묶이지 않는다. 기관이 여러 이룸이를 지원하는 경우는 별도 구독이 아니라
 * {@code PROFILE_MAX_COUNT} 권한으로 표현된다.
 *
 * <p><b>행이 없으면 Free로 본다.</b> 이 규칙 덕분에 기존 회원을 옮기는 작업이 필요 없다.
 * 새로 가입하는 계정에는 가입 시점에 Free 행을 만들어 둔다 — 관리자 화면에서 모든
 * 계정의 구독 상태가 같은 모양으로 보이게 하기 위해서다.
 */
@Entity
@Getter
@Setter
public class Subscription extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @OneToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "member_id", nullable = false, unique = true)
  private Member member;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false)
  private PlanType plan = PlanType.FREE;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false)
  private SubscriptionStatus status = SubscriptionStatus.ACTIVE;

  private LocalDateTime startedAt;

  /// null이면 기간 제한이 없다. Free와 관리자 무기한 발급이 여기 해당한다.
  private LocalDateTime expiresAt;

  /// 이 구독이 어떻게 생겼는가. 결제를 붙일 자리다.
  @Enumerated(EnumType.STRING)
  @Column(nullable = false)
  private SubscriptionSource source = SubscriptionSource.SIGNUP;

  /// 스토어 구독 ID·영수증 식별자. 결제를 붙이기 전까지는 항상 null이다.
  private String externalRef;

  /// 관리자가 켠 이유. 나중에 "이 계정은 왜 Pro지"에 답하려면 있어야 한다.
  @Column(length = 500)
  private String memo;

  /**
   * 지금 이 시각에 실제로 유효한 플랜.
   *
   * <p>상태가 ACTIVE가 아니거나 만료일이 지났으면 Free로 떨어진다. <b>만료를 조회
   * 시점에 계산하므로 상태를 바꿔주는 배치가 필요 없다.</b>
   */
  public PlanType effectivePlan(LocalDateTime now) {
    if (status != SubscriptionStatus.ACTIVE) {
      return PlanType.FREE;
    }
    if (expiresAt != null && expiresAt.isBefore(now)) {
      return PlanType.FREE;
    }
    return plan;
  }
}
