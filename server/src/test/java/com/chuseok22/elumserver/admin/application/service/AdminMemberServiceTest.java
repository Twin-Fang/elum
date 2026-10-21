package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberDetailResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberResponse;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminMemberList;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository.MemberAiUsage;
import com.chuseok22.elumserver.auth.application.service.RefreshTokenService;
import com.chuseok22.elumserver.auth.infrastructure.entity.RevokeReason;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.application.service.SubscriptionHistoryService;
import com.chuseok22.elumserver.license.application.service.SubscriptionService;
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.infrastructure.entity.Subscription;
import com.chuseok22.elumserver.license.infrastructure.entity.SubscriptionHistory;
import com.chuseok22.elumserver.member.application.service.WithdrawnMemberService;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.entity.ProfileGuardian;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository.MemberRoutineCount;
import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.Mockito;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

@ExtendWith(MockitoExtension.class)
class AdminMemberServiceTest {

  @Mock
  private MemberRepository memberRepository;

  @Mock
  private ProfileRepository profileRepository;

  @Mock
  private RoutineRepository routineRepository;

  @Mock
  private ProfileGuardianRepository profileGuardianRepository;

  @Mock
  private AiCallLogRepository aiCallLogRepository;

  @Mock
  private RefreshTokenService refreshTokenService;

  @Mock
  private SubscriptionService subscriptionService;

  @Mock
  private SubscriptionHistoryService subscriptionHistoryService;

  @Mock
  private WithdrawnMemberService withdrawnMemberService;

  @InjectMocks
  private AdminMemberService adminMemberService;

  private Member member(String id, String username) {
    Member member = new Member();
    member.setId(id);
    member.setUsername(username);
    member.setStatus(MemberStatus.ACTIVE);
    return member;
  }

  private AdminListQuery query(String q, Map<String, String> filters, String sort, String page) {
    return AdminListQuery.of(q, filters, sort, page, AdminMemberList.DEFINITION);
  }

  private AdminListQuery defaultQuery() {
    return query(null, Map.of(), null, null);
  }

  /// searchForAdmin 에 실제로 넘어간 인자를 잡는다
  private record SearchCall(boolean hasKeyword, String pattern, Collection<MemberStatus> statuses,
                            String planFilter, Pageable pageable) {
  }

  private SearchCall stubSearchAndCapture(Page<Member> result, Runnable search) {
    when(memberRepository.searchForAdmin(anyBoolean(), any(), any(), any(), any(), any(), any(), any(Pageable.class)))
      .thenReturn(result);
    search.run();
    ArgumentCaptor<Boolean> hasKeyword = ArgumentCaptor.forClass(Boolean.class);
    ArgumentCaptor<String> pattern = ArgumentCaptor.forClass(String.class);
    ArgumentCaptor<Collection<MemberStatus>> statuses = ArgumentCaptor.forClass(Collection.class);
    ArgumentCaptor<String> planFilter = ArgumentCaptor.forClass(String.class);
    ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
    verify(memberRepository).searchForAdmin(hasKeyword.capture(), pattern.capture(), statuses.capture(),
      planFilter.capture(), any(), any(), any(), pageable.capture());
    return new SearchCall(hasKeyword.getValue(), pattern.getValue(), statuses.getValue(),
      planFilter.getValue(), pageable.getValue());
  }

  private MemberRoutineCount routineCount(String memberId, long count) {
    return new MemberRoutineCount() {
      @Override
      public String getMemberId() {
        return memberId;
      }

      @Override
      public long getRoutineCount() {
        return count;
      }
    };
  }

  private MemberAiUsage aiUsage(String memberId, long calls, long tokens, double cost) {
    return new MemberAiUsage() {
      @Override
      public String getMemberId() {
        return memberId;
      }

      @Override
      public long getCallCount() {
        return calls;
      }

      @Override
      public long getTotalTokens() {
        return tokens;
      }

      @Override
      public double getTotalCostUsd() {
        return cost;
      }
    };
  }

  @Test
  @DisplayName("search는 회원별 루틴수와 AI 사용량을 집계 쿼리로 붙여 반환한다")
  void search_attachesAggregates() {
    Member member = member("m1", "parent1");
    when(memberRepository.searchForAdmin(anyBoolean(), any(), any(), any(), any(), any(), any(), any(Pageable.class)))
      .thenReturn(new PageImpl<>(List.of(member)));
    when(routineRepository.countByMemberIds(List.of("m1")))
      .thenReturn(List.of(routineCount("m1", 3)));
    when(aiCallLogRepository.aggregateUsageByMemberIds(List.of("m1")))
      .thenReturn(List.of(aiUsage("m1", 12, 34567, 0.12)));

    Page<AdminMemberResponse> result = adminMemberService.search(defaultQuery());

    AdminMemberResponse response = result.getContent().get(0);
    assertThat(response.routineCount()).isEqualTo(3);
    assertThat(response.aiCallCount()).isEqualTo(12);
    assertThat(response.totalTokens()).isEqualTo(34567);
    assertThat(response.estimatedCostUsd()).isEqualTo(0.12);
  }

  @Test
  @DisplayName("S6 검색어가 있으면 이스케이프한 LIKE 패턴으로 찾고 탈퇴 계정은 뺀다")
  void search_withKeyword_usesEscapedPatternAndExcludesWithdrawn() {
    SearchCall call = stubSearchAndCapture(new PageImpl<>(List.of()),
      () -> adminMemberService.search(query("  하_늘%  ", Map.of(), null, null)));

    assertThat(call.hasKeyword()).isTrue();
    assertThat(call.pattern()).isEqualTo("%하\\_늘\\%%");
    assertThat(call.statuses()).containsExactlyInAnyOrder(MemberStatus.ACTIVE, MemberStatus.SUSPENDED);
  }

  @Test
  @DisplayName("검색어가 없으면 키워드 조건을 건너뛰라고 알린다")
  void search_withoutKeyword_skipsKeywordCondition() {
    SearchCall call = stubSearchAndCapture(new PageImpl<>(List.of()),
      () -> adminMemberService.search(defaultQuery()));

    assertThat(call.hasKeyword()).isFalse();
  }

  @Test
  @DisplayName("상태 필터가 있으면 그 상태만 조회한다")
  void search_withStatusFilter_queriesThatStatusOnly() {
    SearchCall call = stubSearchAndCapture(new PageImpl<>(List.of()),
      () -> adminMemberService.search(query(null, Map.of("status", "SUSPENDED"), null, null)));

    assertThat(call.statuses()).containsExactly(MemberStatus.SUSPENDED);
  }

  @Test
  @DisplayName("요금제 필터 PRO 는 그대로 넘기고, 허용 밖 값은 필터 없음(ALL)으로 보정한다")
  void search_planFilter_allowedValuePassedAndUnknownFallsBackToAll() {
    SearchCall pro = stubSearchAndCapture(new PageImpl<>(List.of()),
      () -> adminMemberService.search(query(null, Map.of("plan", "PRO"), null, null)));
    assertThat(pro.planFilter()).isEqualTo("PRO");

    Mockito.clearInvocations(memberRepository);
    SearchCall unknown = stubSearchAndCapture(new PageImpl<>(List.of()),
      () -> adminMemberService.search(query(null, Map.of("plan", "GOLD' or 1=1"), null, null)));
    assertThat(unknown.planFilter()).isEqualTo("ALL");
  }

  @Test
  @DisplayName("정렬은 허용 열만 받는다 — 요금제 정렬은 구독 열로, 허용 밖은 가입일 최신순으로 돌아간다")
  void search_sort_allowedKeysOnlyElseDefault() {
    SearchCall byPlan = stubSearchAndCapture(new PageImpl<>(List.of()),
      () -> adminMemberService.search(query(null, Map.of(), "plan,asc", null)));
    Sort.Order planOrder = byPlan.pageable().getSort().getOrderFor("s.plan");
    assertThat(planOrder).isNotNull();
    assertThat(planOrder.isAscending()).isTrue();

    Mockito.clearInvocations(memberRepository);
    SearchCall injected = stubSearchAndCapture(new PageImpl<>(List.of()),
      () -> adminMemberService.search(query(null, Map.of(), "passwordHash,asc", null)));
    Sort.Order defaultOrder = injected.pageable().getSort().getOrderFor("createdAt");
    assertThat(defaultOrder).isNotNull();
    assertThat(defaultOrder.isDescending()).isTrue();
    assertThat(injected.pageable().getSort().getOrderFor("passwordHash")).isNull();
  }

  @Test
  @DisplayName("범위 밖 페이지는 마지막 페이지로 맞춰 다시 조회한다")
  void search_pageBeyondLast_requeriesLastPage() {
    Page<Member> empty = new PageImpl<>(List.of(), org.springframework.data.domain.PageRequest.of(8, 20), 41);
    Page<Member> last = new PageImpl<>(List.of(), org.springframework.data.domain.PageRequest.of(2, 20), 41);
    when(memberRepository.searchForAdmin(anyBoolean(), any(), any(), any(), any(), any(), any(), any(Pageable.class)))
      .thenReturn(empty, last);

    Page<AdminMemberResponse> result = adminMemberService.search(query(null, Map.of(), null, "9"));

    assertThat(result.getNumber()).isEqualTo(2);
    ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
    verify(memberRepository, org.mockito.Mockito.times(2))
      .searchForAdmin(anyBoolean(), any(), any(), any(), any(), any(), any(), pageable.capture());
    assertThat(pageable.getAllValues().get(1).getPageNumber()).isEqualTo(2);
  }

  @Test
  @DisplayName("목록 행에 지금 유효한 요금제와 마지막 변경(시각·변경자)이 붙는다 — 구독·이력은 각각 한 번만 조회")
  void search_attachesEffectivePlanAndLastChange() {
    Member proMember = member("m1", "parent1");
    Member freeMember = member("m2", "parent2");
    Subscription pro = new Subscription();
    pro.setMember(proMember);
    pro.setPlan(PlanType.PRO);
    pro.setExpiresAt(LocalDateTime.now().plusDays(10));
    Subscription expiredPro = new Subscription();
    expiredPro.setMember(freeMember);
    expiredPro.setPlan(PlanType.PRO);
    expiredPro.setExpiresAt(LocalDateTime.now().minusDays(1));
    SubscriptionHistory change = new SubscriptionHistory();
    change.setMemberId("m1");
    change.setChangedAt(LocalDateTime.of(2026, 10, 18, 9, 0));
    change.setChangedBy("admin1");
    when(memberRepository.searchForAdmin(anyBoolean(), any(), any(), any(), any(), any(), any(), any(Pageable.class)))
      .thenReturn(new PageImpl<>(List.of(proMember, freeMember)));
    when(subscriptionService.findAllByMemberIds(List.of("m1", "m2"))).thenReturn(Map.of("m1", pro, "m2", expiredPro));
    when(subscriptionHistoryService.latestByMemberIds(List.of("m1", "m2"))).thenReturn(Map.of("m1", change));

    List<AdminMemberResponse> rows = adminMemberService.search(defaultQuery()).getContent();

    assertThat(rows.get(0).plan()).isEqualTo(PlanType.PRO);
    assertThat(rows.get(0).planExpiresAt()).isEqualTo(pro.getExpiresAt());
    assertThat(rows.get(0).planLastChangedAt()).isEqualTo(change.getChangedAt());
    assertThat(rows.get(0).planLastChangedBy()).isEqualTo("admin1");
    // 만료된 Pro 는 Free 로 보이고, 이력이 없으면 마지막 변경도 비어 있다
    assertThat(rows.get(1).plan()).isEqualTo(PlanType.FREE);
    assertThat(rows.get(1).planLastChangedAt()).isNull();
  }

  @Test
  @DisplayName("suspend/unsuspend는 회원 상태를 전환한다")
  void suspendAndUnsuspend_togglesStatus() {
    Member member = member("m1", "parent1");
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member));

    adminMemberService.suspend("m1");
    assertThat(member.getStatus()).isEqualTo(MemberStatus.SUSPENDED);
    // 정지만 하고 세션을 두면 리프레시로 계속 접속을 시도한다.
    verify(refreshTokenService).revokeAll("m1", RevokeReason.SUSPENDED);

    adminMemberService.unsuspend("m1");
    assertThat(member.getStatus()).isEqualTo(MemberStatus.ACTIVE);
  }

  @Test
  @DisplayName("forceLogout은 tokenInvalidBefore를 현재 시각으로 설정한다")
  void forceLogout_setsTokenInvalidBefore() {
    Member member = member("m1", "parent1");
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member));

    adminMemberService.forceLogout("m1");

    assertThat(member.getTokenInvalidBefore()).isNotNull();
    // 액세스 토큰만 막으면 리프레시로 곧바로 다시 들어온다.
    verify(refreshTokenService).revokeAll("m1", RevokeReason.FORCE_LOGOUT);
  }

  @Test
  @DisplayName("getDetail은 AI 사용량과 최근 호출 이력을 함께 담는다")
  void getDetail_includesAiUsageAndRecentCalls() {
    Member member = member("m1", "parent1");
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member));
    when(routineRepository.findAllByCreatedBy("m1")).thenReturn(List.of());
    when(aiCallLogRepository.aggregateUsageByMemberIds(anyList()))
      .thenReturn(List.of(aiUsage("m1", 5, 1000, 0.01)));
    when(aiCallLogRepository.findTop20ByMemberIdOrderByCreatedAtDesc("m1")).thenReturn(List.of());

    AdminMemberDetailResponse detail = adminMemberService.getDetail("m1");

    assertThat(detail.aiCallCount()).isEqualTo(5);
    assertThat(detail.totalTokens()).isEqualTo(1000);
    assertThat(detail.recentAiCalls()).isEmpty();
  }
  private Member withdrawnMember(String id, LocalDateTime withdrawnAt) {
    Member member = member(id, "kakao_" + id);
    member.setStatus(MemberStatus.WITHDRAWN);
    member.setWithdrawnAt(withdrawnAt);
    return member;
  }

  @Test
  @DisplayName("S6 상태 필터가 없으면 탈퇴 계정을 뺀 목록을 본다")
  void search_default_excludesWithdrawn() {
    SearchCall call = stubSearchAndCapture(new PageImpl<>(List.of()),
      () -> adminMemberService.search(defaultQuery()));

    // 탈퇴 계정이 섞이면 운영자가 "활성 회원"을 셀 때 헷갈리고, 지워 달라는 사람이 목록에 계속 보인다.
    assertThat(call.statuses()).doesNotContain(MemberStatus.WITHDRAWN);
  }

  @Test
  @DisplayName("S6 탈퇴 필터로 보면 탈퇴 계정과 보관 만료 예정일이 나온다")
  void search_withdrawnFilter_showsRetentionExpiry() {
    LocalDateTime withdrawnAt = LocalDateTime.of(2026, 9, 23, 10, 0);
    Member member = withdrawnMember("m9", withdrawnAt);
    when(memberRepository.searchForAdmin(anyBoolean(), any(), any(), any(), any(), any(), any(), any(Pageable.class)))
      .thenReturn(new PageImpl<>(List.of(member)));
    when(withdrawnMemberService.retentionExpiresAt(member)).thenReturn(withdrawnAt.plusDays(365));

    Page<AdminMemberResponse> result = adminMemberService.search(
      query(null, Map.of("status", "WITHDRAWN"), null, null));

    AdminMemberResponse row = result.getContent().get(0);
    assertThat(row.status()).isEqualTo(MemberStatus.WITHDRAWN);
    assertThat(row.withdrawnAt()).isEqualTo(withdrawnAt);
    assertThat(row.retentionExpiresAt()).isEqualTo(withdrawnAt.plusDays(365));
  }

  @Test
  @DisplayName("S6 대시보드 회원 수와 최근 활동 회원 수에서 탈퇴 계정을 뺀다")
  void dashboardCounts_excludeWithdrawn() {
    when(memberRepository.countByStatusNot(MemberStatus.WITHDRAWN)).thenReturn(7L);
    when(memberRepository.countByLastActivityAtAfterAndStatusNot(any(LocalDateTime.class),
      eq(MemberStatus.WITHDRAWN))).thenReturn(3L);

    assertThat(adminMemberService.count()).isEqualTo(7L);
    assertThat(adminMemberService.countActiveWithinDays(7)).isEqualTo(3L);
    // 전에는 탈퇴하면 행이 사라졌다. 행을 남기게 됐으니 세는 쪽이 빼야 숫자가 전과 같다.
    verify(memberRepository, never()).count();
  }

  @Test
  @DisplayName("S6 상세 화면에 탈퇴 시각과 보관 만료 예정일이 나온다")
  void getDetail_withdrawn_showsRetention() {
    LocalDateTime withdrawnAt = LocalDateTime.of(2026, 9, 23, 10, 0);
    Member member = withdrawnMember("m9", withdrawnAt);
    when(memberRepository.findById("m9")).thenReturn(Optional.of(member));
    when(routineRepository.findAllByCreatedBy("m9")).thenReturn(List.of());
    when(aiCallLogRepository.aggregateUsageByMemberIds(anyList())).thenReturn(List.of());
    when(aiCallLogRepository.findTop20ByMemberIdOrderByCreatedAtDesc("m9")).thenReturn(List.of());
    when(withdrawnMemberService.retentionExpiresAt(member)).thenReturn(withdrawnAt.plusDays(365));

    AdminMemberDetailResponse detail = adminMemberService.getDetail("m9");

    assertThat(detail.withdrawnAt()).isEqualTo(withdrawnAt);
    assertThat(detail.retentionExpiresAt()).isEqualTo(withdrawnAt.plusDays(365));
  }

  @Test
  @DisplayName("S9 관리자가 탈퇴 계정을 즉시 완전 삭제한다 — 정보주체 삭제 요구")
  void purgeNow_withdrawn_purges() {
    Member member = withdrawnMember("m9", LocalDateTime.now().minusDays(3));
    when(memberRepository.findById("m9")).thenReturn(Optional.of(member));

    adminMemberService.purgeNow("m9", "admin");

    verify(withdrawnMemberService).purge("m9");
  }

  @Test
  @DisplayName("S9 탈퇴하지 않은 계정은 즉시 완전 삭제할 수 없다")
  void purgeNow_active_refuses() {
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member("m1", "parent1")));

    // 쓰는 중인 계정을 관리자 버튼 하나로 지우면 이룸이 일과까지 한 번에 사라진다. 먼저 탈퇴해야 한다.
    assertThatThrownBy(() -> adminMemberService.purgeNow("m1", "admin"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.MEMBER_NOT_WITHDRAWN));
    verify(withdrawnMemberService, never()).purge(any());
  }

  @Test
  @DisplayName("탈퇴 계정에는 정지·정지 해제·강제 로그아웃·Pro 발급·회수를 할 수 없다")
  void withdrawnMember_refusesAccountActions() {
    Member member = withdrawnMember("m9", LocalDateTime.now().minusDays(3));
    when(memberRepository.findById("m9")).thenReturn(Optional.of(member));

    // 정지 해제가 ACTIVE 로 바꾸면 동의·프로필 없이 되살아나고, 정지하면 보관 만료 정리에서 빠진다.
    for (Runnable action : List.<Runnable>of(
      () -> adminMemberService.suspend("m9"),
      () -> adminMemberService.unsuspend("m9"),
      () -> adminMemberService.forceLogout("m9"),
      () -> adminMemberService.grantPro("m9", 30, "시연", "admin"),
      () -> adminMemberService.revokePro("m9", "정리", "admin"))) {
      assertThatThrownBy(action::run)
        .isInstanceOf(CustomException.class)
        .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
          .isEqualTo(ErrorCode.MEMBER_WITHDRAWN));
    }
    assertThat(member.getStatus()).isEqualTo(MemberStatus.WITHDRAWN);
    verify(subscriptionService, never()).grantPro(any(), any(), any(), any());
    verify(subscriptionService, never()).revokePro(any(), any(), any());
    verify(refreshTokenService, never()).revokeAll(any(), any());
  }

  @Test
  @DisplayName("회원 목록의 이룸이는 관계로 붙인다 — 가장 먼저 합류한 이룸이")
  void search_attachesEarliestJoinedProfileThroughRelation() {
    Member member = member("m1", "parent1");
    Profile first = new Profile();
    first.setNickname("하늘");
    Profile later = new Profile();
    later.setNickname("바다");
    ProfileGuardian g1 = new ProfileGuardian();
    g1.setMember(member);
    g1.setProfile(first);
    ProfileGuardian g2 = new ProfileGuardian();
    g2.setMember(member);
    g2.setProfile(later);
    when(memberRepository.searchForAdmin(anyBoolean(), any(), any(), any(), any(), any(), any(), any(Pageable.class)))
      .thenReturn(new PageImpl<>(List.of(member)));
    when(profileGuardianRepository.findAllWithProfileByMemberIdIn(List.of("m1"))).thenReturn(List.of(g1, g2));

    AdminMemberResponse response = adminMemberService.search(defaultQuery()).getContent().get(0);

    assertThat(response.nickname()).isEqualTo("하늘");
  }

  @Test
  @DisplayName("E32 정지해도 그 사람의 일과와 관계는 남는다 — 나간 것이 아니다")
  void e32_suspend_keepsRoutinesAndRelations() {
    Member member = member("m1", "parent1");
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member));

    adminMemberService.suspend("m1");

    verifyNoInteractions(routineRepository, profileGuardianRepository, profileRepository);
  }

  @Test
  @DisplayName("E35 강제 로그아웃은 그 보호자의 토큰 전부를 끊는다 — 그가 붙인 이룸이 휴대폰도 sub 가 같아 함께 끊긴다(받아들인 동작)")
  void e35_forceLogout_revokesEveryTokenIncludingLinkedPhones() {
    Member member = member("m1", "parent1");
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member));

    adminMemberService.forceLogout("m1");

    verify(refreshTokenService).revokeAll("m1", RevokeReason.FORCE_LOGOUT);
  }
}
