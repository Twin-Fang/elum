package com.chuseok22.elumserver.auth.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.auth.application.dto.response.TokenResponse;
import com.chuseok22.elumserver.auth.infrastructure.entity.AuthIdentity;
import com.chuseok22.elumserver.auth.infrastructure.oauth.OAuthProvider;
import com.chuseok22.elumserver.auth.infrastructure.oauth.OAuthUser;
import com.chuseok22.elumserver.auth.infrastructure.oauth.OAuthVerifier;
import com.chuseok22.elumserver.auth.infrastructure.repository.AuthIdentityRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import com.chuseok22.elumserver.common.infrastructure.properties.JwtProperties;
import com.chuseok22.elumserver.license.application.service.SubscriptionService;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

@ExtendWith(MockitoExtension.class)
class OAuthLoginServiceTest {

  @Mock
  private AuthIdentityRepository authIdentityRepository;

  @Mock
  private MemberRepository memberRepository;

  @Mock
  private ProfileRepository profileRepository;

  @Mock
  private SubscriptionService subscriptionService;

  @Mock
  private PasswordEncoder passwordEncoder;

  @Mock
  private JwtProvider jwtProvider;

  @Mock
  private JwtProperties jwtProperties;

  @Mock
  private RefreshTokenService refreshTokenService;

  private OAuthLoginService oAuthLoginService;

  /** 제공자 호출 없이 정해진 신원을 돌려주는 검증기. 실제 검증은 각 Verifier의 책임이다. */
  private record StubVerifier(OAuthProvider provider, OAuthUser result) implements OAuthVerifier {

    @Override
    public OAuthUser verify(String token) {
      return result;
    }
  }

  @BeforeEach
  void setUp() {
    OAuthVerifier kakao = new StubVerifier(
      OAuthProvider.KAKAO, new OAuthUser("kakao-9999", "parent@kakao.com", true));
    oAuthLoginService = new OAuthLoginService(
      List.of(kakao), authIdentityRepository, memberRepository, profileRepository,
      subscriptionService, passwordEncoder, jwtProvider, jwtProperties, refreshTokenService);
  }

  private Member existingMember(MemberStatus status) {
    Member member = new Member();
    member.setId("m1");
    member.setUsername("kakao_kakao-9999");
    member.setStatus(status);
    member.setLoginCount(4);
    return member;
  }

  private void stubTokenIssue(String memberId, String username) {
    when(jwtProvider.createAccessToken(memberId, username)).thenReturn("access-token");
    when(jwtProperties.accessExpMillis()).thenReturn(86400000L);
    when(refreshTokenService.issue(memberId, "device-1")).thenReturn("refresh-token");
  }

  @Test
  @DisplayName("지원하지 않는 제공자는 400으로 거절한다")
  void login_unknownProvider_throwsUnsupported() {
    assertThatThrownBy(() -> oAuthLoginService.login("line", "token", "device-1"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.OAUTH_PROVIDER_UNSUPPORTED));
  }

  @Test
  @DisplayName("등록되지 않은 제공자로 오면 계정을 만들지 않는다")
  void login_providerWithoutVerifier_throwsUnsupported() {
    assertThatThrownBy(() -> oAuthLoginService.login("google", "token", "device-1"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.OAUTH_PROVIDER_UNSUPPORTED));

    verify(memberRepository, never()).save(any(Member.class));
  }

  @Test
  @DisplayName("이미 연결된 신원이면 새 계정을 만들지 않고 기존 계정으로 로그인한다")
  void login_existingIdentity_logsInWithoutCreatingAccount() {
    AuthIdentity identity = new AuthIdentity();
    identity.setMemberId("m1");
    Member member = existingMember(MemberStatus.ACTIVE);

    when(authIdentityRepository.findByProviderAndProviderUserId(OAuthProvider.KAKAO, "kakao-9999"))
      .thenReturn(Optional.of(identity));
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member));
    stubTokenIssue("m1", "kakao_kakao-9999");

    TokenResponse response = oAuthLoginService.login("kakao", "provider-token", "device-1");

    assertThat(response.accessToken()).isEqualTo("access-token");
    assertThat(response.refreshToken()).isEqualTo("refresh-token");
    assertThat(member.getLoginCount()).isEqualTo(5);
    verify(memberRepository, never()).save(any(Member.class));
    verify(profileRepository, never()).save(any(Profile.class));
  }

  @Test
  @DisplayName("처음 보는 신원이면 계정·소셜 신원·프로필을 함께 만든다")
  void login_newIdentity_createsAccountIdentityAndProfile() {
    when(authIdentityRepository.findByProviderAndProviderUserId(OAuthProvider.KAKAO, "kakao-9999"))
      .thenReturn(Optional.empty());
    when(authIdentityRepository.findFirstByEmailAndEmailVerifiedTrue("parent@kakao.com"))
      .thenReturn(Optional.empty());
    when(passwordEncoder.encode(anyString())).thenReturn("encoded");
    when(memberRepository.save(any(Member.class))).thenAnswer(invocation -> {
      Member saved = invocation.getArgument(0);
      saved.setId("new-m");
      return saved;
    });
    stubTokenIssue("new-m", "kakao_kakao-9999");

    TokenResponse response = oAuthLoginService.login("kakao", "provider-token", "device-1");

    assertThat(response.accessToken()).isEqualTo("access-token");

    verify(authIdentityRepository).save(org.mockito.ArgumentMatchers.argThat(saved ->
      saved.getProvider() == OAuthProvider.KAKAO
        && "kakao-9999".equals(saved.getProviderUserId())
        && "new-m".equals(saved.getMemberId())
        && saved.isEmailVerified()
    ));
    // 가입 즉시 당사자 프로필이 생겨야 이후 조회가 "프로필 없음"을 분기하지 않는다.
    verify(profileRepository).save(org.mockito.ArgumentMatchers.argThat(saved ->
      saved.getCharacter() == CharacterType.LULU
    ));
  }

  @Test
  @DisplayName("검증된 이메일이 이미 가입돼 있으면 합치지 않고 409로 알린다")
  void login_verifiedEmailAlreadyTaken_throwsConflict() {
    when(authIdentityRepository.findByProviderAndProviderUserId(OAuthProvider.KAKAO, "kakao-9999"))
      .thenReturn(Optional.empty());
    when(authIdentityRepository.findFirstByEmailAndEmailVerifiedTrue("parent@kakao.com"))
      .thenReturn(Optional.of(new AuthIdentity()));

    assertThatThrownBy(() -> oAuthLoginService.login("kakao", "provider-token", "device-1"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.OAUTH_EMAIL_CONFLICT));

    // 이메일만 같다는 이유로 남의 계정에 올라타는 경로를 막는다.
    verify(memberRepository, never()).save(any(Member.class));
    verify(authIdentityRepository, never()).save(any(AuthIdentity.class));
  }

  @Test
  @DisplayName("정지된 계정은 소셜 로그인으로도 들어올 수 없다")
  void login_suspendedMember_throwsSuspended() {
    AuthIdentity identity = new AuthIdentity();
    identity.setMemberId("m1");

    when(authIdentityRepository.findByProviderAndProviderUserId(OAuthProvider.KAKAO, "kakao-9999"))
      .thenReturn(Optional.of(identity));
    when(memberRepository.findById("m1")).thenReturn(Optional.of(existingMember(MemberStatus.SUSPENDED)));

    assertThatThrownBy(() -> oAuthLoginService.login("kakao", "provider-token", "device-1"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.MEMBER_SUSPENDED));

    verify(refreshTokenService, never()).issue(anyString(), anyString());
  }
}
