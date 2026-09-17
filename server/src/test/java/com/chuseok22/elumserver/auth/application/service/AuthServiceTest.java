package com.chuseok22.elumserver.auth.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
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

  @Mock
  private RefreshTokenService refreshTokenService;

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

    assertThatThrownBy(() -> authService.login(new LoginRequest("parent1", "pw"), null))
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
    when(jwtProperties.accessExpMillis()).thenReturn(86400000L);
    when(refreshTokenService.issue("m1", "device-1")).thenReturn("refresh-token");

    TokenResponse response = authService.login(new LoginRequest("parent1", "pw"), "device-1");

    assertThat(response.accessToken()).isEqualTo("access-token");
    assertThat(response.refreshToken()).isEqualTo("refresh-token");
    assertThat(member.getLastLoginAt()).isNotNull();
    assertThat(member.getLastActivityAt()).isNotNull();
    assertThat(member.getLoginCount()).isEqualTo(3);
  }

  @Test
  @DisplayName("토큰 갱신에 성공하면 새 accessToken과 회전된 refreshToken을 함께 돌려준다")
  void refresh_success_returnsRotatedTokens() {
    Member member = member(MemberStatus.ACTIVE);
    when(refreshTokenService.rotate("old-refresh", "device-1"))
      .thenReturn(new RefreshTokenService.RotationResult("m1", "new-refresh"));
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member));
    when(jwtProvider.createAccessToken("m1", "parent1")).thenReturn("new-access");
    when(jwtProperties.accessExpMillis()).thenReturn(86400000L);

    TokenResponse response = authService.refresh("old-refresh", "device-1");

    assertThat(response.accessToken()).isEqualTo("new-access");
    assertThat(response.refreshToken()).isEqualTo("new-refresh");
    // 갱신은 활동으로 친다 — 앱을 쓰고 있다는 뜻이다.
    assertThat(member.getLastActivityAt()).isNotNull();
    // 갱신은 로그인이 아니므로 로그인 횟수는 늘지 않는다.
    assertThat(member.getLoginCount()).isEqualTo(2);
  }

  @Test
  @DisplayName("정지된 계정은 리프레시 토큰이 살아 있어도 갱신되지 않고 남은 세션까지 끊긴다")
  void refresh_suspendedMember_revokesAllSessions() {
    when(refreshTokenService.rotate("old-refresh", null))
      .thenReturn(new RefreshTokenService.RotationResult("m1", "new-refresh"));
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member(MemberStatus.SUSPENDED)));

    assertThatThrownBy(() -> authService.refresh("old-refresh", null))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.MEMBER_SUSPENDED));

    verify(refreshTokenService).revokeAll("m1");
    verify(jwtProvider, never()).createAccessToken(org.mockito.ArgumentMatchers.anyString(),
      org.mockito.ArgumentMatchers.anyString());
  }

  @Test
  @DisplayName("로그아웃은 해당 계정의 리프레시 토큰을 끊는다")
  void logout_revokesRefreshToken() {
    authService.logout("some-refresh");

    verify(refreshTokenService).revokeByToken("some-refresh");
  }
}
