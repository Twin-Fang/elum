package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberDetailResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminSubscriptionSummary;
import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberResponse;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository.MemberAiUsage;
import com.chuseok22.elumserver.auth.application.service.RefreshTokenService;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.application.service.SubscriptionService;
import com.chuseok22.elumserver.member.application.service.WithdrawnMemberService;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository.MemberRoutineCount;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AdminMemberService {

  private static final int PAGE_SIZE = 20;

  private final MemberRepository memberRepository;

  private final ProfileRepository profileRepository;
  private final RoutineRepository routineRepository;
  private final AiCallLogRepository aiCallLogRepository;
  private final RefreshTokenService refreshTokenService;
  private final SubscriptionService subscriptionService;
  private final WithdrawnMemberService withdrawnMemberService;

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

    // 회원 수만큼 프로필을 따로 조회하지 않는다 — 한 번에 받아 맵으로 쓴다.
    Map<String, Profile> profiles = memberIds.isEmpty() ? Map.of()
      : profileRepository.findAllByMemberIdIn(memberIds).stream()
        .collect(Collectors.toMap(p -> p.getMember().getId(), Function.identity(), (a, b) -> a));

    return members.map(member -> AdminMemberResponse.of(
      member,
      profiles.get(member.getId()),
      routineCounts.getOrDefault(member.getId(), 0L),
      aiUsages.get(member.getId()),
      withdrawnMemberService.retentionExpiresAt(member)
    ));
  }

  public AdminMemberDetailResponse getDetail(String memberId) {
    Member member = findOrThrow(memberId);
    List<Routine> routines = routineRepository.findAllByProfileMemberId(memberId);
    Profile profile = profileRepository.findFirstByMemberIdOrderByCreatedAtAsc(memberId).orElse(null);
    MemberAiUsage aiUsage = aiCallLogRepository.aggregateUsageByMemberIds(List.of(memberId)).stream()
      .findFirst().orElse(null);
    return AdminMemberDetailResponse.of(
      member, profile, routines, aiUsage,
      aiCallLogRepository.findTop20ByMemberIdOrderByCreatedAtDesc(memberId),
      subscriptionService.find(memberId)
        .map(AdminSubscriptionSummary::from)
        .orElseGet(AdminSubscriptionSummary::none),
      withdrawnMemberService.retentionExpiresAt(member)
    );
  }

  /**
   * Pro를 켠다. 결제가 아직 없으므로 지금은 이 경로가 유일하게 Pro를 만드는 방법이다.
   *
   * @param days null이면 무기한
   */
  // 이 클래스는 기본이 읽기 전용이다. 붙이지 않으면 읽기 전용 트랜잭션에 참여해
  // 저장이 flush되지 않고 조용히 사라진다 — 로그도 화면도 성공으로 보이는데 아무 일도
  // 일어나지 않는다. 실제로 그렇게 배포됐다.
  @Transactional
  public void grantPro(String memberId, Integer days, String memo) {
    requireNotWithdrawn(memberId);
    LocalDateTime expiresAt = (days == null || days <= 0) ? null : LocalDateTime.now().plusDays(days);
    subscriptionService.grantPro(memberId, expiresAt, memo);
  }

  @Transactional
  public void revokePro(String memberId) {
    requireNotWithdrawn(memberId);
    subscriptionService.revokePro(memberId, "관리자 회수");
  }

  // 탈퇴해도 행이 남는다 (#372). 전에는 탈퇴하면 행이 사라져 세지 않았으므로 빼야 숫자가 전과 같다.
  public long count() {
    return memberRepository.countByStatusNot(MemberStatus.WITHDRAWN);
  }

  public long countSuspended() {
    return memberRepository.countByStatus(MemberStatus.SUSPENDED);
  }

  // 최근 7일 내 활동(lastActivityAt) 기록이 있는 회원수 — 대시보드 활성 회원 지표.
  public long countActiveWithinDays(int days) {
    return memberRepository.countByLastActivityAtAfterAndStatusNot(
      LocalDateTime.now().minusDays(days), MemberStatus.WITHDRAWN);
  }

  // 계정 정지 — 로그인과 API 사용(MemberAccessGuard)이 모두 차단된다.
  @Transactional
  public void suspend(String memberId) {
    requireNotWithdrawn(memberId).setStatus(MemberStatus.SUSPENDED);
    // 남은 리프레시 토큰을 끊지 않으면 정지된 계정이 갱신으로 계속 접속을 시도한다.
    refreshTokenService.revokeAll(memberId);
  }

  @Transactional
  public void unsuspend(String memberId) {
    requireNotWithdrawn(memberId).setStatus(MemberStatus.ACTIVE);
  }

  // 강제 로그아웃 — 지금 이전에 발급된 모든 토큰이 무효화된다(JWT iat 비교).
  @Transactional
  public void forceLogout(String memberId) {
    requireNotWithdrawn(memberId).setTokenInvalidBefore(LocalDateTime.now());
    // 액세스 토큰만 막으면 리프레시로 새 토큰을 받아 그대로 다시 들어온다.
    // 강제 로그아웃이 성립하려면 세션 자체를 끊어야 한다.
    refreshTokenService.revokeAll(memberId);
  }

  /**
   * 탈퇴 계정을 보관 기간을 기다리지 않고 바로 완전히 지운다 (#372 S9).
   *
   * <p>정보주체가 삭제를 요구하면(개인정보보호법 제36조) 부정 이용 방지를 이유로 계속 남겨 둘지는
   * 운영자가 판단한다. 그 판단 뒤에 누르는 버튼이다. 누가 언제 지웠는지 로그로 남긴다.
   *
   * <p>탈퇴한 계정만 지운다 — 쓰는 중인 계정을 이 버튼 하나로 지우면 이룸이 일과까지 사라진다.
   */
  @Transactional
  public void purgeNow(String memberId, String adminUsername) {
    Member member = findOrThrow(memberId);
    if (member.getStatus() != MemberStatus.WITHDRAWN) {
      throw new CustomException(ErrorCode.MEMBER_NOT_WITHDRAWN);
    }
    withdrawnMemberService.purge(memberId);
    log.info("관리자가 탈퇴 계정을 즉시 완전 삭제했습니다: memberId={}, admin={}", memberId, adminUsername);
  }

  // 상태 필터가 없으면 탈퇴 계정을 뺀다 (#372 S6). 탈퇴 계정은 "탈퇴" 필터로만 본다.
  private Page<Member> findMembers(String keyword, MemberStatus status, Pageable pageable) {
    if (keyword.isEmpty() && status == null) {
      return memberRepository.findByStatusNot(MemberStatus.WITHDRAWN, pageable);
    }
    if (keyword.isEmpty()) {
      return memberRepository.findByStatus(status, pageable);
    }
    if (status == null) {
      return memberRepository.searchByKeywordAndStatusNot(keyword, MemberStatus.WITHDRAWN, pageable);
    }
    return memberRepository.searchByKeywordAndStatus(keyword, status, pageable);
  }

  private String normalize(String keyword) {
    return keyword == null ? "" : keyword.trim();
  }

  /**
   * 탈퇴 계정에는 정지·해제·강제 로그아웃·요금제 변경을 하지 않는다.
   * 정지 해제가 ACTIVE 로 바꾸면 동의·프로필 없이 되살아나고, 정지하면 WITHDRAWN 이 아니게 되어
   * 보관 만료 정리에서 빠진다.
   */
  private Member requireNotWithdrawn(String memberId) {
    Member member = findOrThrow(memberId);
    if (member.getStatus() == MemberStatus.WITHDRAWN) {
      throw new CustomException(ErrorCode.MEMBER_WITHDRAWN);
    }
    return member;
  }

  private Member findOrThrow(String memberId) {
    return memberRepository.findById(memberId)
      .orElseThrow(() -> new CustomException(ErrorCode.MEMBER_NOT_FOUND));
  }
}
