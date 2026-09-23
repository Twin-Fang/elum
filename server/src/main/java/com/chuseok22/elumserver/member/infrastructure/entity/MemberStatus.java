package com.chuseok22.elumserver.member.infrastructure.entity;

import lombok.AllArgsConstructor;
import lombok.Getter;

// 회원 계정 상태. SUSPENDED는 로그인·API 사용이 모두 차단된다.
// WITHDRAWN은 탈퇴한 계정이다. 보관 기간 동안 행만 남아 있고 API는 막힌다 (이슈 #372).
@Getter
@AllArgsConstructor
public enum MemberStatus {

  ACTIVE("활성"),
  SUSPENDED("정지"),
  WITHDRAWN("탈퇴"),
  ;

  private final String label;
}
