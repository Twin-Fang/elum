package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberDetailResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberResponse;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.time.LocalDateTime;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AdminMemberService {

  private final MemberRepository memberRepository;
  private final RoutineRepository routineRepository;

  public List<AdminMemberResponse> getAll() {
    return memberRepository.findAll().stream()
      .map(AdminMemberResponse::from)
      .toList();
  }

  public AdminMemberDetailResponse getDetail(String memberId) {
    Member member = memberRepository.findById(memberId)
      .orElseThrow(() -> new CustomException(ErrorCode.MEMBER_NOT_FOUND));
    List<Routine> routines = routineRepository.findAllByMemberId(memberId);
    return AdminMemberDetailResponse.of(member, routines);
  }

  public long count() {
    return memberRepository.count();
  }

  // 계정 정지 — 로그인과 API 사용(MemberAccessGuard)이 모두 차단된다.
  @Transactional
  public void suspend(String memberId) {
    findOrThrow(memberId).setStatus(MemberStatus.SUSPENDED);
  }

  @Transactional
  public void unsuspend(String memberId) {
    findOrThrow(memberId).setStatus(MemberStatus.ACTIVE);
  }

  // 강제 로그아웃 — 지금 이전에 발급된 모든 토큰이 무효화된다(JWT iat 비교).
  @Transactional
  public void forceLogout(String memberId) {
    findOrThrow(memberId).setTokenInvalidBefore(LocalDateTime.now());
  }

  private Member findOrThrow(String memberId) {
    return memberRepository.findById(memberId)
      .orElseThrow(() -> new CustomException(ErrorCode.MEMBER_NOT_FOUND));
  }
}
