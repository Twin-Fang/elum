package com.chuseok22.elumserver.auth.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.auth.application.dto.request.LoginRequest;
import com.chuseok22.elumserver.auth.application.dto.response.TokenResponse;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import com.chuseok22.elumserver.common.infrastructure.properties.JwtProperties;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.crypto.password.PasswordEncoder;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

  @Mock
  private MemberRepository memberRepository;

  @Mock
  private PasswordEncoder passwordEncoder;

  @Mock
  private AuthenticationManager memberAuthenticationManager;

  @Mock
  private JwtProvider jwtProvider;

  @Mock
  private JwtProperties jwtProperties;

  @InjectMocks
  private AuthService authService;

  private Member member(MemberStatus status) {
    Member member = new Member();
    member.setId("m1");
    member.setUsername("parent1");
    member.setPassword("encoded");
    member.setStatus(status);
    member.setLoginCount(2);
    return member;
  }

  @Test
  @DisplayName("정지된 계정은 비밀번호가 맞아도 MEMBER_SUSPENDED로 로그인이 차단된다")
  void login_suspendedMember_throwsMemberSuspended() {
    when(memberRepository.findByUsername("parent1"))
      .thenReturn(Optional.of(member(MemberStatus.SUSPENDED)));

    assertThatThrownBy(() -> authService.login(new LoginRequest("parent1", "pw")))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.MEMBER_SUSPENDED));
  }

  @Test
  @DisplayName("로그인 성공 시 lastLoginAt·lastActivityAt이 기록되고 loginCount가 증가한다")
  void login_success_recordsLoginActivity() {
    Member member = member(MemberStatus.ACTIVE);
    when(memberRepository.findByUsername("parent1")).thenReturn(Optional.of(member));
    when(jwtProvider.createAccessToken("m1", "parent1")).thenReturn("access-token");
    when(jwtProperties.accessExpMillis()).thenReturn(3600000L);

    TokenResponse response = authService.login(new LoginRequest("parent1", "pw"));

    assertThat(response.accessToken()).isEqualTo("access-token");
    assertThat(member.getLastLoginAt()).isNotNull();
    assertThat(member.getLastActivityAt()).isNotNull();
    assertThat(member.getLoginCount()).isEqualTo(3);
  }
}
