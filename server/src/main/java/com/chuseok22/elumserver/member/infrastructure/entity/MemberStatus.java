package com.chuseok22.elumserver.member.infrastructure.entity;

import lombok.AllArgsConstructor;
import lombok.Getter;

// 회원 계정 상태. SUSPENDED는 로그인·API 사용이 모두 차단된다.
@Getter
@AllArgsConstructor
public enum MemberStatus {

  ACTIVE("활성"),
  SUSPENDED("정지"),
  ;

  private final String label;
}
