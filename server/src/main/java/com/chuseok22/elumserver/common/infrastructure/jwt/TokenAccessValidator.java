package com.chuseok22.elumserver.common.infrastructure.jwt;

import java.util.Date;

// JWT 서명 검증 이후의 접근 허용 판단(계정 정지·강제 로그아웃)을 위임하는 인터페이스.
// 구현은 member 도메인(MemberAccessGuard)에 있다 — common이 member 패키지를 직접
// 의존하지 않도록 인터페이스만 여기에 둔다(SecurityConfig의 UserDetailsService와 같은 패턴).
public interface TokenAccessValidator {

  boolean isAllowed(String memberId, Date tokenIssuedAt);
}
