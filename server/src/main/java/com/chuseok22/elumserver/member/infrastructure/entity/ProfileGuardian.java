package com.chuseok22.elumserver.member.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.LocalDateTime;
import lombok.Getter;
import lombok.Setter;

/**
 * 보호자 한 사람과 이룸이 한 명을 잇는 관계 (다중 보호자 명세 4-1).
 *
 * <p>이룸이는 여러 사람에게서 일과를 받는다 — 엄마·아빠·센터 복지사. {@code profile.member_id}
 * 하나로는 두 번째 보호자가 붙을 자리가 없어서 관계를 표로 뗐다.
 *
 * <p><b>윗사람이 없다.</b> 연결된 보호자는 모두 동등하다. {@link #kind}는 화면에서 부르는 이름일
 * 뿐이고, 권한은 {@code ProfileAccessGuard} 한 곳에서 정한다.
 */
@Entity
@Getter
@Setter
@Table(
  name = "profile_guardian",
  uniqueConstraints = @UniqueConstraint(name = "uk_profile_guardian", columnNames = {"profile_id", "member_id"}),
  indexes = @Index(name = "idx_profile_guardian_member", columnList = "member_id")
)
public class ProfileGuardian extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "profile_id", nullable = false)
  private Profile profile;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "member_id", nullable = false)
  private Member member;

  /** 표시용. 권한에 쓰지 않는다. */
  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 30)
  private GuardianKind kind = GuardianKind.GUARDIAN;

  /**
   * 이 이룸이에 붙은 시각. 기본 이룸이(가장 먼저 합류한 이룸이)와 대표 보호자 넘기기(남은 사람 중
   * 가장 먼저 합류한 사람)가 이 값으로 정해진다.
   */
  @Column(name = "joined_at", nullable = false)
  private LocalDateTime joinedAt;
}
