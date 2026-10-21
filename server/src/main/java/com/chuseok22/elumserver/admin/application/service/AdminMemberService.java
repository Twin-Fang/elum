package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberConnections;
import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberDetailResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminSubscriptionSummary;
import com.chuseok22.elumserver.admin.application.dto.response.AdminSubscriptionHistoryLine;
import com.chuseok22.elumserver.admin.application.list.AdminCsvExporter;
import com.chuseok22.elumserver.admin.application.list.AdminCsvExporter.ExportRows;
import com.chuseok22.elumserver.admin.application.list.AdminListDefaults;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminMemberList;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository.MemberAiUsage;
import com.chuseok22.elumserver.auth.application.service.AuthIdentityQueryService;
import com.chuseok22.elumserver.auth.application.service.RefreshTokenService;
import com.chuseok22.elumserver.auth.infrastructure.entity.RevokeReason;
import com.chuseok22.elumserver.auth.infrastructure.oauth.OAuthProvider;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.application.service.SubscriptionHistoryService;
import com.chuseok22.elumserver.license.application.service.SubscriptionService;
import com.chuseok22.elumserver.license.infrastructure.entity.Subscription;
import com.chuseok22.elumserver.license.infrastructure.entity.SubscriptionHistory;
import com.chuseok22.elumserver.member.application.service.WithdrawnMemberService;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.entity.ProfileGuardian;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository.MemberGuardianshipCount;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository.MemberRoutineCount;
import java.time.LocalDateTime;
import java.util.Arrays;
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

  /// 회원 상세에 보여줄 요금제 이력 최대 건수
  private static final int PLAN_HISTORY_LIMIT = 50;
  /// 요금제 필터 없음 (MemberRepository.searchForAdmin 의 planFilter 값)
  private static final String PLAN_FILTER_ALL = "ALL";

  private final MemberRepository memberRepository;

  private final ProfileRepository profileRepository;
  private final RoutineRepository routineRepository;
  private final ProfileGuardianRepository profileGuardianRepository;
  private final AiCallLogRepository aiCallLogRepository;
  private final RefreshTokenService refreshTokenService;
  private final AuthIdentityQueryService authIdentityQueryService;
  private final SubscriptionService subscriptionService;
  private final SubscriptionHistoryService subscriptionHistoryService;
  private final WithdrawnMemberService withdrawnMemberService;
  private final AdminMemberConnectionService adminMemberConnectionService;

  /**
   * 회원 목록: 조건 쿼리 1회 > 페이지 회원의 집계 보강(루틴수, AI 사용량, 이룸이, 구독, 마지막 변경, 이룸이·보호자 수, 로그인 제공자 각 1회)
   * 회원 수만큼 쿼리하지 않음. 범위 밖 페이지는 마지막 페이지로 맞춰 다시 조회
   */
  public Page<AdminMemberResponse> search(AdminListQuery query) {
    Page<Member> members = findMembers(query);
    if (members.getTotalPages() > 0 && query.page() > members.getTotalPages()) {
      members = findMembers(query.withTotalPages(members.getTotalPages()));
    }
    return withListDetails(members);
  }

  /**
   * 회원 CSV: 목록과 같은 조건·정렬로 첫 쪽(상한 크기) 조회 > 상한 이내일 때만 목록과 같은 집계 보강
   * 상한을 넘으면 보강 쿼리 없이 건수만 돌려줌
   */
  public ExportRows<AdminMemberResponse> searchForExport(AdminListQuery query) {
    Page<Member> members = findMembers(query, AdminCsvExporter.exportPageable(sortOf(query)));
    if (AdminCsvExporter.isOverLimit(members.getTotalElements())) {
      return ExportRows.overLimit(members.getTotalElements());
    }
    return ExportRows.fromPage(withListDetails(members));
  }

  // 회원 페이지 > 목록 한 줄 응답 (보강 쿼리는 회원 수와 상관없이 종류마다 1회)
  private Page<AdminMemberResponse> withListDetails(Page<Member> members) {
    List<String> memberIds = members.getContent().stream().map(Member::getId).toList();
    Map<String, Long> routineCounts = memberIds.isEmpty() ? Map.of()
      : routineRepository.countByMemberIds(memberIds).stream()
        .collect(Collectors.toMap(MemberRoutineCount::getMemberId, MemberRoutineCount::getRoutineCount));
    Map<String, MemberAiUsage> aiUsages = memberIds.isEmpty() ? Map.of()
      : aiCallLogRepository.aggregateUsageByMemberIds(memberIds).stream()
        .collect(Collectors.toMap(MemberAiUsage::getMemberId, Function.identity()));

    // 회원 수만큼 이룸이를 따로 조회하지 않는다 — 관계를 한 번에 받아 가장 먼저 합류한 이룸이를 붙인다.
    Map<String, Profile> profiles = memberIds.isEmpty() ? Map.of()
      : profileGuardianRepository.findAllWithProfileByMemberIdIn(memberIds).stream()
        .collect(Collectors.toMap(g -> g.getMember().getId(), ProfileGuardian::getProfile, (first, later) -> first));
    Map<String, Subscription> subscriptions = subscriptionService.findAllByMemberIds(memberIds);
    Map<String, SubscriptionHistory> lastPlanChanges = subscriptionHistoryService.latestByMemberIds(memberIds);
    Map<String, MemberGuardianshipCount> guardianshipCounts = memberIds.isEmpty() ? Map.of()
      : profileGuardianRepository.countGuardianshipByMemberIds(memberIds).stream()
        .collect(Collectors.toMap(MemberGuardianshipCount::getMemberId, Function.identity()));
    Map<String, List<OAuthProvider>> loginProviders = authIdentityQueryService.providersByMemberIds(memberIds);

    return members.map(member -> {
      MemberGuardianshipCount guardianship = guardianshipCounts.get(member.getId());
      return AdminMemberResponse.of(
        member,
        profiles.get(member.getId()),
        routineCounts.getOrDefault(member.getId(), 0L),
        aiUsages.get(member.getId()),
        withdrawnMemberService.retentionExpiresAt(member),
        subscriptions.get(member.getId()),
        lastPlanChanges.get(member.getId())
      ).withGuardianshipAndProviders(
        guardianship == null ? 0 : countOrZero(guardianship.getProfileCount()),
        guardianship == null ? 0 : countOrZero(guardianship.getGuardianCount()),
        loginProviders.getOrDefault(member.getId(), List.of()));
    });
  }

  private static long countOrZero(Long count) {
    return count == null ? 0 : count;
  }

  /**
   * 회원 상세: 계정·일과·AI 사용량·요금제 > 연결 정보(이룸이 전부의 보호자·초대 코드·기기, 푸시 기기)
   * 머리글 이름은 기본 이룸이(가장 먼저 합류) 기준. 이룸이 전부는 연결 정보의 카드로 보여줌
   */
  public AdminMemberDetailResponse getDetail(String memberId) {
    Member member = findOrThrow(memberId);
    // 이 사람이 만든 일과 — 이룸이를 함께 돌보면 다른 사람의 일과는 그 사람 화면에 있다.
    List<Routine> routines = routineRepository.findAllByCreatedBy(memberId);
    Profile defaultProfile = profileRepository.findAllGuardedBy(memberId).stream().findFirst().orElse(null);
    MemberAiUsage aiUsage = aiCallLogRepository.aggregateUsageByMemberIds(List.of(memberId)).stream()
      .findFirst().orElse(null);
    AdminMemberDetailResponse detail = AdminMemberDetailResponse.of(
      member, defaultProfile, routines, aiUsage,
      aiCallLogRepository.findTop20ByMemberIdOrderByCreatedAtDesc(memberId),
      subscriptionService.find(memberId)
        .map(AdminSubscriptionSummary::from)
        .orElseGet(AdminSubscriptionSummary::none),
      subscriptionHistoryService.recent(memberId, PLAN_HISTORY_LIMIT).stream()
        .map(AdminSubscriptionHistoryLine::from)
        .toList(),
      withdrawnMemberService.retentionExpiresAt(member)
    );
    return detail.withConnections(findConnectionsOrFailed(memberId));
  }

  /// 이룸이 기기 연결 해제 (확인·세션 폐기·감사 로그는 연결 정보 서비스가 처리)
  @Transactional
  public void unlinkDevice(String memberId, String linkId, String adminUsername) {
    adminMemberConnectionService.unlinkDevice(memberId, linkId, adminUsername);
  }

  // 연결 정보 조회 (다른 트랜잭션). 실패해도 상세 본문은 그대로 열고 그 영역에 오류 코드 표시
  private AdminMemberConnections findConnectionsOrFailed(String memberId) {
    try {
      return adminMemberConnectionService.getConnections(memberId);
    } catch (RuntimeException e) {
      log.warn("[admin member detail] connections load failed : memberId={}", memberId, e);
      return AdminMemberConnections.failed();
    }
  }

  /**
   * Pro를 켠다. 결제가 아직 없으므로 지금은 이 경로가 유일하게 Pro를 만드는 방법이다.
   *
   * @param days  null 이면 무기한
   * @param actor 변경한 관리자 로그인 이름 (요금제 이력에 남음)
   */
  // 이 클래스는 기본이 읽기 전용이다. 붙이지 않으면 읽기 전용 트랜잭션에 참여해
  // 저장이 flush되지 않고 조용히 사라진다 — 로그도 화면도 성공으로 보이는데 아무 일도
  // 일어나지 않는다. 실제로 그렇게 배포됐다.
  @Transactional
  public void grantPro(String memberId, Integer days, String reason, String actor) {
    requireNotWithdrawn(memberId);
    subscriptionService.grantPro(memberId, days, reason, actor);
  }

  @Transactional
  public void revokePro(String memberId, String reason, String actor) {
    requireNotWithdrawn(memberId);
    subscriptionService.revokePro(memberId, reason, actor);
  }

  // 탈퇴해도 행이 남는다. 탈퇴 회원은 세지 않으므로 뺀다.
  public long count() {
    return memberRepository.countByStatusNot(MemberStatus.WITHDRAWN);
  }

  // 지금 유효한 Pro 회원수 (Subscription.effectivePlan 과 같은 기준, 탈퇴 회원 제외) — 대시보드 요금제 분포
  public long countEffectivePro() {
    return subscriptionService.countEffectivePro(LocalDateTime.now());
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
    // 일과·관계는 건드리지 않는다 — 나간 것이 아니다 (다중 보호자 E32). 그가 붙인 이룸이 휴대폰도
    // 토큰 주인(sub)이 같아 함께 막힌다.
    refreshTokenService.revokeAll(memberId, RevokeReason.SUSPENDED);
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
    // 이 보호자가 붙인 이룸이 휴대폰도 토큰 주인(sub)이 같아 함께 끊긴다 — 받아들인 동작이다 (다중 보호자 E35).
    refreshTokenService.revokeAll(memberId, RevokeReason.FORCE_LOGOUT);
  }

  /**
   * 탈퇴 계정을 보관 기간을 기다리지 않고 바로 완전히 지운다.
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

  // 상태 필터가 없으면 탈퇴 계정을 뺀다. 탈퇴 계정은 "탈퇴" 필터로만 본다.
  private Page<Member> findMembers(AdminListQuery query) {
    return findMembers(query, PageRequest.of(query.pageIndex(), AdminListDefaults.PAGE_SIZE, sortOf(query)));
  }

  // 조건 > 회원 페이지 (목록·CSV 공통). 제공자 필터가 없으면 in 이 비지 않게 전체 제공자를 넘김
  private Page<Member> findMembers(AdminListQuery query, Pageable pageable) {
    String statusFilter = query.filters().get(AdminMemberList.FILTER_STATUS);
    List<MemberStatus> statuses = statusFilter == null
      ? Arrays.stream(MemberStatus.values()).filter(status -> status != MemberStatus.WITHDRAWN).toList()
      : List.of(MemberStatus.valueOf(statusFilter));
    String planFilter = query.filters().getOrDefault(AdminMemberList.FILTER_PLAN, PLAN_FILTER_ALL);
    OAuthProvider provider = AdminMemberList.providerOf(query);
    List<OAuthProvider> providers = provider == null ? List.of(OAuthProvider.values()) : List.of(provider);
    return memberRepository.searchForAdmin(
      query.q() != null, query.likePattern(), statuses, planFilter, LocalDateTime.now(),
      AdminMemberList.joinedFromOf(query), AdminMemberList.joinedToExclusiveOf(query),
      AdminMemberList.hasLastActivePeriod(query), AdminMemberList.lastActiveFromOf(query),
      AdminMemberList.lastActiveToExclusiveOf(query), provider != null, providers, pageable);
  }

  // 정렬 열 키 > 엔티티 속성 (허용 열만 들어오므로 그 밖은 기본 정렬). 동률은 id 로 고정해 페이지가 겹치지 않게 한다
  private Sort sortOf(AdminListQuery query) {
    Sort.Direction direction = query.isAscending() ? Sort.Direction.ASC : Sort.Direction.DESC;
    Sort.Order mainOrder = switch (query.sortKey()) {
      case AdminMemberList.SORT_USERNAME -> new Sort.Order(direction, "username");
      // s 는 지금 유효한 Pro 구독뿐이라 Free 는 null 이다: 오름차순은 Free 먼저, 내림차순은 Pro 먼저
      case AdminMemberList.SORT_PLAN -> new Sort.Order(direction, "s.plan").with(
        query.isAscending() ? Sort.NullHandling.NULLS_FIRST : Sort.NullHandling.NULLS_LAST);
      case AdminMemberList.SORT_LAST_ACTIVITY -> new Sort.Order(direction, "lastActivityAt");
      default -> new Sort.Order(direction, "createdAt");
    };
    return Sort.by(mainOrder, new Sort.Order(Sort.Direction.ASC, "id"));
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
