package com.chuseok22.elumserver.member.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Date;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class MemberAccessGuardTest {

  @Mock
  private MemberRepository memberRepository;

  @InjectMocks
  private MemberAccessGuard memberAccessGuard;

  private Member activeMember() {
    Member member = new Member();
    member.setStatus(MemberStatus.ACTIVE);
    return member;
  }

  private Date dateOf(LocalDateTime localDateTime) {
    return Date.from(localDateTime.atZone(ZoneId.systemDefault()).toInstant());
  }

  @Test
  @DisplayName("활성 회원의 유효 토큰은 통과하고 lastActivityAt이 갱신된다")
  void isAllowed_activeMember_returnsTrueAndTouchesActivity() {
    Member member = activeMember();
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member));

    boolean allowed = memberAccessGuard.isAllowed("m1", dateOf(LocalDateTime.now()));

    assertThat(allowed).isTrue();
    assertThat(member.getLastActivityAt()).isNotNull();
  }

  @Test
  @DisplayName("정지된 회원은 서명이 유효해도 거부된다")
  void isAllowed_suspendedMember_returnsFalse() {
    Member member = activeMember();
    member.setStatus(MemberStatus.SUSPENDED);
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member));

    assertThat(memberAccessGuard.isAllowed("m1", dateOf(LocalDateTime.now()))).isFalse();
  }

  @Test
  @DisplayName("tokenInvalidBefore 이전에 발급된 토큰은 거부된다 (강제 로그아웃)")
  void isAllowed_tokenIssuedBeforeInvalidation_returnsFalse() {
    Member member = activeMember();
    member.setTokenInvalidBefore(LocalDateTime.now());
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member));

    boolean allowed = memberAccessGuard.isAllowed("m1", dateOf(LocalDateTime.now().minusHours(1)));

    assertThat(allowed).isFalse();
  }

  @Test
  @DisplayName("tokenInvalidBefore 이후에 발급된 토큰(재로그인)은 통과한다")
  void isAllowed_tokenIssuedAfterInvalidation_returnsTrue() {
    Member member = activeMember();
    member.setTokenInvalidBefore(LocalDateTime.now().minusHours(1));
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member));

    assertThat(memberAccessGuard.isAllowed("m1", dateOf(LocalDateTime.now()))).isTrue();
  }

  @Test
  @DisplayName("S4 탈퇴한 계정의 토큰은 서명이 유효해도 거부된다 — 401")
  void isAllowed_withdrawnMember_returnsFalse() {
    Member member = activeMember();
    member.setStatus(MemberStatus.WITHDRAWN);
    // 발급 시각 기준만으로는 못 막는 경우 — 탈퇴 뒤에 어떤 경로로든 새로 발급된 토큰도 막는다.
    member.setTokenInvalidBefore(LocalDateTime.now().minusHours(1));
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member));

    assertThat(memberAccessGuard.isAllowed("m1", dateOf(LocalDateTime.now()))).isFalse();
    // 탈퇴한 계정을 활동 중으로 세지 않는다.
    assertThat(member.getLastActivityAt()).isNull();
  }

  @Test
  @DisplayName("S4·S8 되살아난 계정이라도 탈퇴 전에 발급된 토큰(예전 이룸이 휴대폰 포함)은 계속 거부된다")
  void isAllowed_revivedMember_oldTokenStillRejected() {
    LocalDateTime withdrawnAt = LocalDateTime.now().minusDays(10);
    Member revived = activeMember();
    revived.setTokenInvalidBefore(withdrawnAt);
    when(memberRepository.findById("m1")).thenReturn(Optional.of(revived));

    assertThat(memberAccessGuard.isAllowed("m1", dateOf(withdrawnAt.minusDays(1)))).isFalse();
    // 되살아난 뒤 새로 로그인해 받은 토큰은 통과한다.
    assertThat(memberAccessGuard.isAllowed("m1", dateOf(LocalDateTime.now()))).isTrue();
  }

  @Test
  @DisplayName("존재하지 않는 회원은 거부된다")
  void isAllowed_missingMember_returnsFalse() {
    when(memberRepository.findById("ghost")).thenReturn(Optional.empty());

    assertThat(memberAccessGuard.isAllowed("ghost", dateOf(LocalDateTime.now()))).isFalse();
  }

  @Test
  @DisplayName("60초 이내에 이미 활동이 기록됐으면 lastActivityAt을 다시 갱신하지 않는다 (스로틀)")
  void isAllowed_recentActivity_doesNotTouchAgain() {
    Member member = activeMember();
    LocalDateTime recent = LocalDateTime.now().minusSeconds(10);
    member.setLastActivityAt(recent);
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member));

    memberAccessGuard.isAllowed("m1", dateOf(LocalDateTime.now()));

    assertThat(member.getLastActivityAt()).isEqualTo(recent);
  }

  @Test
  @DisplayName("DB 조회가 실패하면 가용성을 우선해 통과시킨다")
  void isAllowed_repositoryFailure_returnsTrue() {
    when(memberRepository.findById("m1")).thenThrow(new RuntimeException("DB down"));

    assertThat(memberAccessGuard.isAllowed("m1", dateOf(LocalDateTime.now()))).isTrue();
  }
}
