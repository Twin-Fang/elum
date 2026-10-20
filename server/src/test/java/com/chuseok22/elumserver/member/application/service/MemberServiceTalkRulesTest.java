package com.chuseok22.elumserver.member.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/// 이야기 이용 규칙 동의와 글쓴이 표시용 조회: 동의 시각을 덮어쓰거나 정지 회원이 새는 결함을 막는다.
@ExtendWith(MockitoExtension.class)
class MemberServiceTalkRulesTest {

  @Mock
  private MemberRepository memberRepository;

  @InjectMocks
  private MemberService memberService;

  @Test
  void agreeTalkRules_recordsTimeOnce_andKeepsFirstAgreementTime() {
    Member member = member("member-1", "달리는곰", MemberStatus.ACTIVE);
    when(memberRepository.findById("member-1")).thenReturn(Optional.of(member));

    assertThat(memberService.hasAgreedTalkRules("member-1")).isFalse();
    memberService.agreeTalkRules("member-1");
    LocalDateTime firstAgreedAt = member.getTalkRulesAgreedAt();
    memberService.agreeTalkRules("member-1");

    assertThat(firstAgreedAt).isNotNull();
    assertThat(member.getTalkRulesAgreedAt()).isEqualTo(firstAgreedAt);
    assertThat(memberService.hasAgreedTalkRules("member-1")).isTrue();
  }

  @Test
  void nicknamesOf_skipsMembersWithoutNickname() {
    when(memberRepository.findAllById(List.of("a", "b"))).thenReturn(List.of(
      member("a", "달리는곰", MemberStatus.ACTIVE), member("b", null, MemberStatus.ACTIVE)));

    Map<String, String> nicknames = memberService.nicknamesOf(List.of("a", "b"));

    assertThat(nicknames).containsExactly(Map.entry("a", "달리는곰"));
  }

  @Test
  void suspendedAmong_returnsOnlySuspendedIds() {
    when(memberRepository.findAllById(List.of("a", "b", "c"))).thenReturn(List.of(
      member("a", "가", MemberStatus.ACTIVE), member("b", "나", MemberStatus.SUSPENDED),
      member("c", "다", MemberStatus.WITHDRAWN)));

    Set<String> suspended = memberService.suspendedAmong(List.of("a", "b", "c"));

    assertThat(suspended).containsExactly("b");
  }

  private static Member member(String id, String nickname, MemberStatus status) {
    Member member = new Member();
    member.setId(id);
    member.setNickname(nickname);
    member.setStatus(status);
    return member;
  }
}
