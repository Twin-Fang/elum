package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberDetailResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberResponse;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository.MemberAiUsage;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository.MemberRoutineCount;
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
  private RoutineRepository routineRepository;

  @Mock
  private AiCallLogRepository aiCallLogRepository;

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
    when(memberRepository.findAll(any(Pageable.class)))
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
  @DisplayName("검색어가 있으면 keyword 검색 쿼리를 사용한다")
  void search_withKeyword_usesKeywordQuery() {
    when(memberRepository.searchByKeyword(eq("하늘"), any(Pageable.class)))
      .thenReturn(new PageImpl<>(List.of()));

    adminMemberService.search("  하늘  ", null, 0);

    verify(memberRepository).searchByKeyword(eq("하늘"), any(Pageable.class));
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
  }

  @Test
  @DisplayName("getDetail은 AI 사용량과 최근 호출 이력을 함께 담는다")
  void getDetail_includesAiUsageAndRecentCalls() {
    Member member = member("m1", "parent1");
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member));
    when(routineRepository.findAllByMemberId("m1")).thenReturn(List.of());
    when(aiCallLogRepository.aggregateUsageByMemberIds(anyList()))
      .thenReturn(List.of(aiUsage("m1", 5, 1000, 0.01)));
    when(aiCallLogRepository.findTop20ByMemberIdOrderByCreatedAtDesc("m1")).thenReturn(List.of());

    AdminMemberDetailResponse detail = adminMemberService.getDetail("m1");

    assertThat(detail.aiCallCount()).isEqualTo(5);
    assertThat(detail.totalTokens()).isEqualTo(1000);
    assertThat(detail.recentAiCalls()).isEmpty();
  }
}
