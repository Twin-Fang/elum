package com.chuseok22.elumserver.auth.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.auth.application.dto.request.LoginRequest;
import com.chuseok22.elumserver.auth.application.dto.request.SignUpRequest;
import com.chuseok22.elumserver.auth.application.dto.response.TokenResponse;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import com.chuseok22.elumserver.common.infrastructure.properties.JwtProperties;
import com.chuseok22.elumserver.license.application.service.SubscriptionService;
import com.chuseok22.elumserver.link.core.LinkRole;
import com.chuseok22.elumserver.member.application.service.GuardianshipService;
import com.chuseok22.elumserver.member.application.service.WithdrawnMemberService;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import io.jsonwebtoken.Claims;
import java.time.LocalDateTime;
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

  @Mock
  private WithdrawnMemberService withdrawnMemberService;

  @Mock
  private GuardianshipService guardianshipService;

  @Mock
  private SubscriptionService subscriptionService;

  @InjectMocks
  private AuthService authService;

  /** 목 JwtProvider 로는 어느 오버로드를 불렀는지만 안다. 역할·연결은 실제 토큰을 풀어 본다. */
  private final JwtProvider realJwt = new JwtProvider(new JwtProperties(
    "elum-test-secret-key-elum-test-secret-key-0123456789", 86_400_000L, 15_552_000_000L, "elum-test"));

  private AuthService serviceWithRealJwt() {
    return new AuthService(memberRepository, null, passwordEncoder, memberAuthenticationManager,
      realJwt, jwtProperties, refreshTokenService, null, withdrawnMemberService);
  }

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
      .thenReturn(new RefreshTokenService.RotationResult("m1", "new-refresh", null));
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
      .thenReturn(new RefreshTokenService.RotationResult("m1", "new-refresh", null));
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
  @DisplayName("이룸이 휴대폰 세션을 갱신하면 새 액세스 토큰도 이룸이 역할이고 같은 연결을 담는다")
  void refresh_elumiSession_keepsElumiRoleAndLink() {
    when(refreshTokenService.rotate("elumi-refresh", null))
      .thenReturn(new RefreshTokenService.RotationResult("m1", "new-refresh", "l1"));
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member(MemberStatus.ACTIVE)));

    TokenResponse response = serviceWithRealJwt().refresh("elumi-refresh", null);

    Claims claims = realJwt.parseClaims(response.accessToken());
    // 역할이 빠지면 보호자로 읽혀 일과 삭제·회원 탈퇴·연결 암호 발급이 열린다.
    assertThat(LinkRole.fromClaim(claims.get("role"))).isEqualTo(LinkRole.ELUMI);
    // 연결이 빠지면 보호자가 끊어도 필터가 이 토큰을 막지 못한다.
    assertThat(claims.get("linkId")).isEqualTo("l1");
    assertThat(claims.getSubject()).isEqualTo("m1");
    assertThat(response.refreshToken()).isEqualTo("new-refresh");
  }

  @Test
  @DisplayName("보호자 세션 갱신은 그대로 보호자 토큰이다")
  void refresh_guardianSession_staysGuardian() {
    when(refreshTokenService.rotate("guardian-refresh", null))
      .thenReturn(new RefreshTokenService.RotationResult("m1", "new-refresh", null));
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member(MemberStatus.ACTIVE)));

    TokenResponse response = serviceWithRealJwt().refresh("guardian-refresh", null);

    Claims claims = realJwt.parseClaims(response.accessToken());
    assertThat(LinkRole.fromClaim(claims.get("role"))).isEqualTo(LinkRole.GUARDIAN);
    assertThat(claims.get("linkId")).isNull();
  }

  @Test
  @DisplayName("E33 로그아웃은 그 기기 세션만 끊는다")
  void e33_logout_revokesOnlyThatDeviceSession() {
    authService.logout("some-refresh");

    verify(refreshTokenService).revokeSession("some-refresh");
    verify(refreshTokenService, never()).revokeAll(org.mockito.ArgumentMatchers.anyString());
  }
  @Test
  @DisplayName("S1 보관 중인 탈퇴 계정에 아이디·비밀번호로 로그인하면 새 계정 없이 이전 계정을 되살린다")
  void login_withdrawnWithinRetention_revives() {
    Member member = member(MemberStatus.WITHDRAWN);
    member.setWithdrawnAt(LocalDateTime.now().minusDays(10));
    when(memberRepository.findByUsername("parent1")).thenReturn(Optional.of(member));
    when(withdrawnMemberService.isRetentionExpired(member)).thenReturn(false);
    when(jwtProvider.createAccessToken("m1", "parent1")).thenReturn("access-token");
    when(jwtProperties.accessExpMillis()).thenReturn(86400000L);
    when(refreshTokenService.issue("m1", "device-1")).thenReturn("refresh-token");

    TokenResponse response = authService.login(new LoginRequest("parent1", "pw"), "device-1");

    // 비밀번호 확인(authenticate)을 통과한 뒤에만 되살린다 — 아이디만 알아서는 되살릴 수 없다.
    verify(memberAuthenticationManager).authenticate(org.mockito.ArgumentMatchers.any());
    verify(withdrawnMemberService).revive(member);
    // 같은 회원 ID 로 토큰이 나가야 AI 사용 기록과 한도가 이어진다.
    assertThat(response.accessToken()).isEqualTo("access-token");
  }

  @Test
  @DisplayName("S2 보관 기간이 지난 탈퇴 계정은 아이디로 로그인할 수 없다 — 없는 계정으로 본다")
  void login_withdrawnPastRetention_rejected() {
    Member member = member(MemberStatus.WITHDRAWN);
    member.setWithdrawnAt(LocalDateTime.now().minusDays(400));
    when(memberRepository.findByUsername("parent1")).thenReturn(Optional.of(member));
    when(withdrawnMemberService.isRetentionExpired(member)).thenReturn(true);

    assertThatThrownBy(() -> authService.login(new LoginRequest("parent1", "pw"), "device-1"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.INVALID_CREDENTIALS));

    // 기간이 지난 것을 되살리면 약속한 보관 기간을 넘겨 기록을 잇게 된다. 곧 스케줄러가 지운다.
    verify(withdrawnMemberService, never()).revive(org.mockito.ArgumentMatchers.any());
    verify(refreshTokenService, never()).issue(org.mockito.ArgumentMatchers.anyString(),
      org.mockito.ArgumentMatchers.anyString());
  }

  @Test
  @DisplayName("S4 탈퇴한 계정은 남은 리프레시 토큰으로 갱신할 수 없다 — 401")
  void refresh_withdrawnMember_rejected() {
    when(refreshTokenService.rotate("old-refresh", null))
      .thenReturn(new RefreshTokenService.RotationResult("m1", "new-refresh", null));
    Member member = member(MemberStatus.WITHDRAWN);
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member));

    assertThatThrownBy(() -> authService.refresh("old-refresh", null))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.REFRESH_TOKEN_INVALID));

    // 갱신은 되살리기 경로가 아니다 — 되살리려면 소셜·아이디 로그인을 다시 거쳐야 한다.
    verify(withdrawnMemberService, never()).revive(org.mockito.ArgumentMatchers.any());
    assertThat(member.getStatus()).isEqualTo(MemberStatus.WITHDRAWN);
    verify(jwtProvider, never()).createAccessToken(org.mockito.ArgumentMatchers.anyString(),
      org.mockito.ArgumentMatchers.anyString());
  }

  @Test
  @DisplayName("가입하면 이룸이를 관계와 함께 만든다 — 관계가 없으면 새 서버가 그 이룸이를 못 찾는다")
  void signUp_createsProfileThroughGuardianship() {
    when(memberRepository.existsByUsername("parent1")).thenReturn(false);
    when(passwordEncoder.encode("pw")).thenReturn("encoded");

    authService.signUp(new SignUpRequest("parent1", "pw"));

    verify(guardianshipService).createOwnProfile(
      org.mockito.ArgumentMatchers.argThat(member -> "parent1".equals(member.getUsername())));
  }
}
