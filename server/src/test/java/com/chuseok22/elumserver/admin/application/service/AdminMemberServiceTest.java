package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberDetailResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberResponse;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository.MemberAiUsage;
import com.chuseok22.elumserver.auth.application.service.RefreshTokenService;
import com.chuseok22.elumserver.auth.infrastructure.entity.RevokeReason;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.application.service.SubscriptionService;
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
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;

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
    when(memberRepository.findByStatusNot(eq(MemberStatus.WITHDRAWN), any(Pageable.class)))
      .thenReturn(new PageImpl<>(List.of(member)));
    when(routineRepository.countByMemberIds(List.of("m1")))
      .thenReturn(List.of(routineCount("m1", 3)));
    when(aiCallLogRepository.aggregateUsageByMemberIds(List.of("m1")))
      .thenReturn(List.of(aiUsage("m1", 12, 34567, 0.12)));

    Page<AdminMemberResponse> result = adminMemberService.search(null, null, 0);

    AdminMemberResponse response = result.getContent().get(0);
    assertThat(response.routineCount()).isEqualTo(3);
    assertThat(response.aiCallCount()).isEqualTo(12);
    assertThat(response.totalTokens()).isEqualTo(34567);
    assertThat(response.estimatedCostUsd()).isEqualTo(0.12);
  }

  @Test
  @DisplayName("S6 검색어만 있으면 탈퇴 계정을 뺀 keyword 검색 쿼리를 사용한다")
  void search_withKeyword_usesKeywordQuery() {
    when(memberRepository.searchByKeywordAndStatusNot(eq("하늘"), eq(MemberStatus.WITHDRAWN), any(Pageable.class)))
      .thenReturn(new PageImpl<>(List.of()));

    adminMemberService.search("  하늘  ", null, 0);

    verify(memberRepository).searchByKeywordAndStatusNot(eq("하늘"), eq(MemberStatus.WITHDRAWN), any(Pageable.class));
    verify(memberRepository, never()).searchByKeyword(any(), any(Pageable.class));
  }

  @Test
  @DisplayName("상태 필터만 있으면 findByStatus를 사용한다")
  void search_withStatusOnly_usesStatusQuery() {
    when(memberRepository.findByStatus(eq(MemberStatus.SUSPENDED), any(Pageable.class)))
      .thenReturn(new PageImpl<>(List.of()));

    adminMemberService.search("", MemberStatus.SUSPENDED, 0);

    verify(memberRepository).findByStatus(eq(MemberStatus.SUSPENDED), any(Pageable.class));
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
    when(memberRepository.findByStatusNot(eq(MemberStatus.WITHDRAWN), any(Pageable.class)))
      .thenReturn(new PageImpl<>(List.of()));

    adminMemberService.search(null, null, 0);

    // 탈퇴 계정이 섞이면 운영자가 "활성 회원"을 셀 때 헷갈리고, 지워 달라는 사람이 목록에 계속 보인다.
    verify(memberRepository, never()).findAll(any(Pageable.class));
  }

  @Test
  @DisplayName("S6 탈퇴 필터로 보면 탈퇴 계정과 보관 만료 예정일이 나온다")
  void search_withdrawnFilter_showsRetentionExpiry() {
    LocalDateTime withdrawnAt = LocalDateTime.of(2026, 9, 23, 10, 0);
    Member member = withdrawnMember("m9", withdrawnAt);
    when(memberRepository.findByStatus(eq(MemberStatus.WITHDRAWN), any(Pageable.class)))
      .thenReturn(new PageImpl<>(List.of(member)));
    when(withdrawnMemberService.retentionExpiresAt(member)).thenReturn(withdrawnAt.plusDays(365));

    Page<AdminMemberResponse> result = adminMemberService.search(null, MemberStatus.WITHDRAWN, 0);

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
      () -> adminMemberService.grantPro("m9", 30, "시연"),
      () -> adminMemberService.revokePro("m9"))) {
      assertThatThrownBy(action::run)
        .isInstanceOf(CustomException.class)
        .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
          .isEqualTo(ErrorCode.MEMBER_WITHDRAWN));
    }
    assertThat(member.getStatus()).isEqualTo(MemberStatus.WITHDRAWN);
    verify(subscriptionService, never()).grantPro(any(), any(), any());
    verify(subscriptionService, never()).revokePro(any(), any());
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
    when(memberRepository.findByStatusNot(eq(MemberStatus.WITHDRAWN), any(Pageable.class)))
      .thenReturn(new PageImpl<>(List.of(member)));
    when(profileGuardianRepository.findAllWithProfileByMemberIdIn(List.of("m1"))).thenReturn(List.of(g1, g2));

    AdminMemberResponse response = adminMemberService.search(null, null, 0).getContent().get(0);

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
