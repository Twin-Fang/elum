package com.chuseok22.elumserver.member.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class MemberNicknameServiceTest {

  @Mock
  private MemberRepository memberRepository;

  // 깨지면: 짧은 닉네임이 계속 겹칠 때 유니크 위반으로 가입이 실패함
  @Test
  @DisplayName("짧은 후보가 모두 겹치면 긴 숫자 닉네임으로 넘어간다")
  void fallsBackToLongNumberWhenShortCandidatesCollide() {
    when(memberRepository.existsByNickname(anyString())).thenReturn(true);

    String nickname = new MemberNicknameService(memberRepository).generateUniqueNickname();

    assertThat(nickname).matches(".+-\\d{8}");
  }

  // 깨지면: 다시 로그인하거나 기동할 때마다 보호자 닉네임이 바뀜
  @Test
  @DisplayName("이미 닉네임이 있으면 바꾸지 않는다")
  void keepsExistingNickname() {
    Member member = new Member();
    member.setNickname("가파른블록-1269");

    new MemberNicknameService(memberRepository).assignIfAbsent(member);

    assertThat(member.getNickname()).isEqualTo("가파른블록-1269");
  }
}
