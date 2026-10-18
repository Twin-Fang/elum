package com.chuseok22.elumserver.license.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.core.SubscriptionHistoryAction;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import java.time.LocalDateTime;
import lombok.Getter;
import lombok.Setter;

/**
 * 요금제 부여·회수 한 건: 변경자, 전/후 요금제, 기간, 사유, 시각
 * 변경마다 한 줄씩 쌓고 고치지 않음 (회원 외래키 없음, 완전 삭제 때 함께 지움)
 */
@Entity
@Getter
@Setter
public class SubscriptionHistory extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(nullable = false)
  private String memberId;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false)
  private SubscriptionHistoryAction action;

  /// 변경 직전에 실제로 유효하던 요금제
  @Enumerated(EnumType.STRING)
  @Column(nullable = false)
  private PlanType beforePlan;

  /// 변경 직후에 실제로 유효한 요금제
  @Enumerated(EnumType.STRING)
  @Column(nullable = false)
  private PlanType afterPlan;

  /// 부여 기간(일). null 이면 무기한이거나 회수
  private Integer durationDays;

  private LocalDateTime beforeExpiresAt;

  private LocalDateTime afterExpiresAt;

  @Column(nullable = false, length = 500)
  private String reason;

  /// 변경한 관리자 로그인 이름
  @Column(nullable = false)
  private String changedBy;

  @Column(nullable = false)
  private LocalDateTime changedAt;
}
