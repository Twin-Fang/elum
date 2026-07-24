package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberDetailResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberResponse;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository.MemberAiUsage;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository.MemberRoutineCount;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AdminMemberService {

  private static final int PAGE_SIZE = 20;

  private final MemberRepository memberRepository;
  private final RoutineRepository routineRepository;
  private final AiCallLogRepository aiCallLogRepository;

  // 검색어·상태 필터 조합에 따라 파생/JPQL 쿼리를 선택하고, 페이지에 실린 회원들의
  // 루틴수·AI 사용량을 group by 집계 2번으로 붙인다(회원 수만큼 쿼리 금지).
  public Page<AdminMemberResponse> search(String keyword, MemberStatus status, int page) {
    Pageable pageable = PageRequest.of(Math.max(page, 0), PAGE_SIZE, Sort.by(Sort.Direction.DESC, "createdAt"));
    Page<Member> members = findMembers(normalize(keyword), status, pageable);

    List<String> memberIds = members.getContent().stream().map(Member::getId).toList();
    Map<String, Long> routineCounts = memberIds.isEmpty() ? Map.of()
      : routineRepository.countByMemberIds(memberIds).stream()
        .collect(Collectors.toMap(MemberRoutineCount::getMemberId, MemberRoutineCount::getRoutineCount));
    Map<String, MemberAiUsage> aiUsages = memberIds.isEmpty() ? Map.of()
      : aiCallLogRepository.aggregateUsageByMemberIds(memberIds).stream()
        .collect(Collectors.toMap(MemberAiUsage::getMemberId, Function.identity()));

    return members.map(member -> AdminMemberResponse.of(
      member,
      routineCounts.getOrDefault(member.getId(), 0L),
      aiUsages.get(member.getId())
    ));
  }

  public AdminMemberDetailResponse getDetail(String memberId) {
    Member member = findOrThrow(memberId);
    List<Routine> routines = routineRepository.findAllByMemberId(memberId);
    MemberAiUsage aiUsage = aiCallLogRepository.aggregateUsageByMemberIds(List.of(memberId)).stream()
      .findFirst().orElse(null);
    return AdminMemberDetailResponse.of(
      member, routines, aiUsage, aiCallLogRepository.findTop20ByMemberIdOrderByCreatedAtDesc(memberId)
    );
  }

  public long count() {
    return memberRepository.count();
  }

  public long countSuspended() {
    return memberRepository.countByStatus(MemberStatus.SUSPENDED);
  }

  // 최근 7일 내 활동(lastActivityAt) 기록이 있는 회원수 — 대시보드 활성 회원 지표.
  public long countActiveWithinDays(int days) {
    return memberRepository.countByLastActivityAtAfter(LocalDateTime.now().minusDays(days));
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

  private Page<Member> findMembers(String keyword, MemberStatus status, Pageable pageable) {
    if (keyword.isEmpty() && status == null) {
      return memberRepository.findAll(pageable);
    }
    if (keyword.isEmpty()) {
      return memberRepository.findByStatus(status, pageable);
    }
    if (status == null) {
      return memberRepository.searchByKeyword(keyword, pageable);
    }
    return memberRepository.searchByKeywordAndStatus(keyword, status, pageable);
  }

  private String normalize(String keyword) {
    return keyword == null ? "" : keyword.trim();
  }

  private Member findOrThrow(String memberId) {
    return memberRepository.findById(memberId)
      .orElseThrow(() -> new CustomException(ErrorCode.MEMBER_NOT_FOUND));
  }
}
