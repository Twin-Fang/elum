package com.chuseok22.elumserver.member.application.service;

import com.chuseok22.elumserver.common.infrastructure.jwt.TokenAccessValidator;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Date;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * JWT 서명이 유효한 요청에 대해 계정 상태 기반 접근을 판단한다.
 * - SUSPENDED 회원 → 거부 (관리자 정지 즉시 기존 토큰도 무력화)
 * - tokenInvalidBefore 이전에 발급된 토큰 → 거부 (강제 로그아웃)
 * - 통과 시 lastActivityAt을 60초 스로틀로 갱신 (요청마다 UPDATE가 나가지 않게)
 * DB 장애 시에는 가용성을 우선해 통과시키고 경고 로그만 남긴다 — 상태 확인 실패로
 * 전체 API가 죽는 것보다 정지 반영이 잠시 늦는 쪽이 낫다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MemberAccessGuard implements TokenAccessValidator {

  private static final long ACTIVITY_THROTTLE_SECONDS = 60;

  private final MemberRepository memberRepository;

  @Override
  @Transactional
  public boolean isAllowed(String memberId, Date tokenIssuedAt) {
    try {
      Member member = memberRepository.findById(memberId).orElse(null);
      if (member == null) {
        return false;
      }
      if (member.getStatus() == MemberStatus.SUSPENDED) {
        return false;
      }
      if (isIssuedBeforeInvalidation(tokenIssuedAt, member.getTokenInvalidBefore())) {
        return false;
      }
      touchActivity(member);
      return true;
    } catch (Exception e) {
      log.warn("회원 접근 상태 확인 실패, 가용성 우선으로 통과: memberId={}", memberId, e);
      return true;
    }
  }

  private boolean isIssuedBeforeInvalidation(Date tokenIssuedAt, LocalDateTime tokenInvalidBefore) {
    if (tokenIssuedAt == null || tokenInvalidBefore == null) {
      return false;
    }
    return tokenIssuedAt.toInstant()
      .isBefore(tokenInvalidBefore.atZone(ZoneId.systemDefault()).toInstant());
  }

  private void touchActivity(Member member) {
    LocalDateTime now = LocalDateTime.now();
    LocalDateTime last = member.getLastActivityAt();
    if (last == null || last.plusSeconds(ACTIVITY_THROTTLE_SECONDS).isBefore(now)) {
      member.setLastActivityAt(now);
    }
  }
}
