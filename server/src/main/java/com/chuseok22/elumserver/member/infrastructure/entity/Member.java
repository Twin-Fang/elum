package com.chuseok22.elumserver.member.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.Set;
import lombok.Getter;
import lombok.Setter;

@Entity
@Getter
@Setter
public class Member extends BaseEntity {
  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(nullable = false, unique = true)
  private String username;

  @Column(nullable = false)
  private String password;

  @Column(nullable = false, columnDefinition = "integer not null default 0")
  private Integer totalStars = 0;

  private String nickname;

  @Enumerated(EnumType.STRING)
  private CharacterType character;

  @ElementCollection(fetch = FetchType.EAGER)
  @CollectionTable(name = "member_support_goals", joinColumns = @JoinColumn(name = "member_id"))
  @Enumerated(EnumType.STRING)
  @Column(name = "support_goal", nullable = false)
  private Set<SupportGoal> supportGoals = new HashSet<>();

  // 계정 상태. SUSPENDED면 로그인·API 사용이 모두 차단된다(MemberAccessGuard).
  @Enumerated(EnumType.STRING)
  @Column(nullable = false, columnDefinition = "varchar(255) not null default 'ACTIVE'")
  private MemberStatus status = MemberStatus.ACTIVE;

  private LocalDateTime lastLoginAt;

  // 인증 요청마다 60초 스로틀로 갱신된다(MemberAccessGuard) — 활성 회원 판단 기준.
  private LocalDateTime lastActivityAt;

  @Column(nullable = false, columnDefinition = "integer not null default 0")
  private Integer loginCount = 0;

  // 이 시각 이전에 발급된 JWT는 거부한다 — 관리자 강제 로그아웃의 구현 수단.
  private LocalDateTime tokenInvalidBefore;
}
