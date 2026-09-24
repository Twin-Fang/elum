package com.chuseok22.elumserver.auth.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.auth.application.dto.response.TokenResponse;
import com.chuseok22.elumserver.auth.infrastructure.entity.AuthIdentity;
import com.chuseok22.elumserver.auth.infrastructure.oauth.OAuthProvider;
import com.chuseok22.elumserver.auth.infrastructure.oauth.OAuthUser;
import com.chuseok22.elumserver.auth.infrastructure.oauth.OAuthVerifier;
import com.chuseok22.elumserver.auth.infrastructure.repository.AuthIdentityRepository;
import com.chuseok22.elumserver.auth.infrastructure.repository.RefreshTokenRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import com.chuseok22.elumserver.common.infrastructure.properties.JwtProperties;
import com.chuseok22.elumserver.credit.application.service.CreditAccountService;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditAccountRepository;
import com.chuseok22.elumserver.license.application.service.SubscriptionService;
import com.chuseok22.elumserver.license.infrastructure.repository.SubscriptionRepository;
import com.chuseok22.elumserver.link.infrastructure.repository.DeviceLinkRepository;
import com.chuseok22.elumserver.member.application.service.GuardianshipService;
import com.chuseok22.elumserver.member.application.service.WithdrawnMemberService;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InOrder;
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
  private ProfileGuardianRepository profileGuardianRepository;

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

  // 탈퇴 계정 되살리기·완전 삭제는 목이 아니라 실제 서비스로 돈다 — 로그인에서 되살아나기까지를 한 번에 본다.
  @Mock
  private RoutineRepository routineRepository;

  @Mock
  private RefreshTokenRepository refreshTokenRepository;

  @Mock
  private AiCallLogRepository aiCallLogRepository;

  @Mock
  private DeviceLinkRepository deviceLinkRepository;

  @Mock
  private SubscriptionRepository subscriptionRepository;

  @Mock
  private SystemConfigService systemConfigService;

  @Mock
  private AiCreditAccountRepository aiCreditAccountRepository;

  @Mock
  private CreditAccountService creditAccountService;

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
    // S3 — 같은 사람이 같은 이메일로 다른 제공자를 쓰는 경우
    OAuthVerifier naver = new StubVerifier(
      OAuthProvider.NAVER, new OAuthUser("naver-1234", "parent@kakao.com", true));
    // 가입·되살리기가 이룸이를 관계와 함께 만드는지까지 보려고 목이 아니라 실제 서비스를 쓴다.
    GuardianshipService guardianshipService = new GuardianshipService(
      profileRepository, profileGuardianRepository, routineRepository, deviceLinkRepository, refreshTokenRepository);
    WithdrawnMemberService withdrawnMemberService = new WithdrawnMemberService(
      memberRepository, authIdentityRepository, refreshTokenRepository, aiCallLogRepository, deviceLinkRepository, subscriptionRepository,
      subscriptionService, systemConfigService, guardianshipService, aiCreditAccountRepository);
    oAuthLoginService = new OAuthLoginService(
      List.of(kakao, naver), authIdentityRepository, memberRepository, guardianshipService,
      subscriptionService, passwordEncoder, jwtProvider, jwtProperties, refreshTokenService,
      withdrawnMemberService, creditAccountService);
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
    // 관계 한 줄도 함께 — 새 서버는 관계 표로 이룸이를 찾는다 (다중 보호자 #360).
    verify(profileGuardianRepository).save(org.mockito.ArgumentMatchers.argThat(guardian ->
      "new-m".equals(guardian.getMember().getId())));
  }

  private void stubNewSignup() {
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
  }

  @Test
  @DisplayName("#407 새로 가입하면 크레딧 계정을 소셜 신원 키로 잇는다 — 재가입이면 떼어 둔 장부가 되붙는다")
  void login_newIdentity_linksCreditAccountByIdentityKey() {
    stubNewSignup();

    oAuthLoginService.login("kakao", "provider-token", "device-1");

    verify(creditAccountService).linkIdentity("new-m", CreditAccountService.identityKey("KAKAO", "kakao-9999"));
  }

  @Test
  @DisplayName("#407 크레딧 계정 연결이 실패해도 로그인은 된다")
  void login_creditLinkFails_loginStillSucceeds() {
    stubNewSignup();
    org.mockito.Mockito.doThrow(new RuntimeException("db down"))
      .when(creditAccountService).linkIdentity(anyString(), anyString());

    TokenResponse response = oAuthLoginService.login("kakao", "provider-token", "device-1");

    assertThat(response.accessToken()).isEqualTo("access-token");
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
  private Member withdrawnMember(LocalDateTime withdrawnAt) {
    Member member = existingMember(MemberStatus.WITHDRAWN);
    member.setWithdrawnAt(withdrawnAt);
    member.setTokenInvalidBefore(withdrawnAt);
    member.setTermsAgreed(true);
    member.setPrivacyAgreed(true);
    member.setOverseasTransferAgreed(true);
    member.setGuardianConfirmed(true);
    member.setConsentedAt(withdrawnAt.minusDays(30));
    return member;
  }

  /** 탈퇴 때 이메일을 비운 채 남겨 둔 소셜 신원 */
  private AuthIdentity retainedIdentity() {
    AuthIdentity identity = new AuthIdentity();
    identity.setMemberId("m1");
    identity.setProvider(OAuthProvider.KAKAO);
    identity.setProviderUserId("kakao-9999");
    identity.setEmail(null);
    identity.setEmailVerified(false);
    return identity;
  }

  @Test
  @DisplayName("S1 보관 중인 탈퇴 계정으로 같은 소셜 로그인을 하면 새 계정 대신 이전 계정을 빈 상태로 되살린다")
  void login_withdrawnWithinRetention_revivesSameAccount() {
    Member member = withdrawnMember(LocalDateTime.now().minusDays(10));
    AuthIdentity identity = retainedIdentity();
    when(authIdentityRepository.findByProviderAndProviderUserId(OAuthProvider.KAKAO, "kakao-9999"))
      .thenReturn(Optional.of(identity));
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member));
    when(systemConfigService.getInt(ConfigKey.MEMBER_WITHDRAWN_RETENTION_DAYS)).thenReturn(365);
    when(authIdentityRepository.findFirstByEmailAndEmailVerifiedTrue("parent@kakao.com"))
      .thenReturn(Optional.empty());
    stubTokenIssue("m1", "kakao_kakao-9999");

    TokenResponse response = oAuthLoginService.login("kakao", "provider-token", "device-1");

    assertThat(response.accessToken()).isEqualTo("access-token");
    // 새 계정을 만들지 않는다 — 같은 회원 ID 로 토큰이 나가야 AI 사용 기록과 하루·주간 한도가 이어진다.
    verify(memberRepository, never()).save(any(Member.class));
    verify(authIdentityRepository, never()).save(any(AuthIdentity.class));
    verify(refreshTokenService).issue("m1", "device-1");
    assertThat(member.getStatus()).isEqualTo(MemberStatus.ACTIVE);
    assertThat(member.getWithdrawnAt()).isNull();
    // 동의는 다시 받는다.
    assertThat(member.hasRequiredConsents()).isFalse();
    // 이룸이·일과 없이 온보딩부터 — 빈 프로필과 Free 구독만 만든다.
    verify(profileRepository).save(org.mockito.ArgumentMatchers.argThat(saved ->
      saved.getMember() == member && saved.getNickname() == null));
    verify(profileGuardianRepository).save(org.mockito.ArgumentMatchers.argThat(guardian ->
      guardian.getMember() == member));
    verify(subscriptionService).createFreeIfAbsent(member);
    // 가입 때처럼 이메일을 다시 적는다 — 새 가입의 이메일 충돌 안내가 이 값을 본다.
    assertThat(identity.getEmail()).isEqualTo("parent@kakao.com");
    assertThat(identity.isEmailVerified()).isTrue();
  }

  @Test
  @DisplayName("S1·S3 되살릴 때 그 이메일을 보관 기간에 다른 계정이 쓰고 있으면 이메일을 적지 않는다")
  void login_revive_emailTakenMeanwhile_leavesEmailEmpty() {
    Member member = withdrawnMember(LocalDateTime.now().minusDays(10));
    AuthIdentity identity = retainedIdentity();
    AuthIdentity naverAccount = new AuthIdentity();
    naverAccount.setMemberId("m-naver");
    when(authIdentityRepository.findByProviderAndProviderUserId(OAuthProvider.KAKAO, "kakao-9999"))
      .thenReturn(Optional.of(identity));
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member));
    when(systemConfigService.getInt(ConfigKey.MEMBER_WITHDRAWN_RETENTION_DAYS)).thenReturn(365);
    when(authIdentityRepository.findFirstByEmailAndEmailVerifiedTrue("parent@kakao.com"))
      .thenReturn(Optional.of(naverAccount));
    stubTokenIssue("m1", "kakao_kakao-9999");

    oAuthLoginService.login("kakao", "provider-token", "device-1");

    // 한 이메일이 두 계정을 가리키면 새 가입의 충돌 안내가 어느 계정인지 모른다.
    assertThat(identity.getEmail()).isNull();
    assertThat(member.getStatus()).isEqualTo(MemberStatus.ACTIVE);
  }

  @Test
  @DisplayName("S2 보관 기간이 지난 탈퇴 계정이면 남은 것을 지우고 새 계정으로 가입시킨다")
  void login_withdrawnPastRetention_purgesAndRegistersNew() {
    Member old = withdrawnMember(LocalDateTime.now().minusDays(400));
    when(authIdentityRepository.findByProviderAndProviderUserId(OAuthProvider.KAKAO, "kakao-9999"))
      .thenReturn(Optional.of(retainedIdentity()));
    when(memberRepository.findById("m1")).thenReturn(Optional.of(old));
    when(systemConfigService.getInt(ConfigKey.MEMBER_WITHDRAWN_RETENTION_DAYS)).thenReturn(365);
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
    // 스케줄러가 아직 못 지웠어도 약속한 기간을 넘겨 잇지 않는다 — 여기서 지우고 새로 시작한다.
    verify(aiCallLogRepository).detachMember("m1");
    verify(authIdentityRepository).deleteAllByMemberId("m1");
    // 옛 행을 DB 에서 먼저 지워야 같은 아이디(kakao_kakao-9999)로 새 행을 넣을 수 있다.
    InOrder order = inOrder(memberRepository);
    order.verify(memberRepository).delete(old);
    order.verify(memberRepository).flush();
    order.verify(memberRepository).save(any(Member.class));
    verify(refreshTokenService).issue("new-m", "device-1");
  }

  @Test
  @DisplayName("S3 다른 소셜 제공자로 오면 새 계정이다 — 탈퇴한 계정과 이어지지 않는다")
  void login_otherProvider_createsNewAccount() {
    when(authIdentityRepository.findByProviderAndProviderUserId(OAuthProvider.NAVER, "naver-1234"))
      .thenReturn(Optional.empty());
    // 탈퇴한 카카오 신원은 이메일을 비워 두었으므로 이메일 충돌로 잡히지 않는다.
    when(authIdentityRepository.findFirstByEmailAndEmailVerifiedTrue("parent@kakao.com"))
      .thenReturn(Optional.empty());
    when(passwordEncoder.encode(anyString())).thenReturn("encoded");
    when(memberRepository.save(any(Member.class))).thenAnswer(invocation -> {
      Member saved = invocation.getArgument(0);
      saved.setId("naver-m");
      return saved;
    });
    stubTokenIssue("naver-m", "naver_naver-1234");

    oAuthLoginService.login("naver", "provider-token", "device-1");

    // 제공자 + 제공자 회원번호가 다르면 같은 사람인지 알 수 없다. 이걸로는 못 막고,
    // 서비스 전체 하루 비용 상한(#368)이 마지막 방어선이다.
    verify(memberRepository).save(any(Member.class));
    verify(memberRepository, never()).findById(anyString());
  }
}
