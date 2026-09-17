package com.chuseok22.elumserver.member.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
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
 * 로그인하는 계정. 보호자 또는 기관 지도자다.
 *
 * <p>당사자 정보(이름·캐릭터·도움 목표·별)는 {@link Profile}로 떼어냈다.
 * 한 테이블에 섞여 있으면 당사자 기기가 접속하려고 보호자의 아이디·비밀번호를
 * 써야 하고, 그 기기를 잃어버리면 계정 전체가 열린다.
 *
 * <p>이름이 {@code Member}인 것은 기존 API 경로(`/api/member/*`)와 응답 형식을
 * 유지하기 위해서다. 이미 배포된 앱이 그 계약을 쓰고 있다.
 */
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
