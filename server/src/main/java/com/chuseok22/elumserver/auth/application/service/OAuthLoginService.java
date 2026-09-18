package com.chuseok22.elumserver.auth.application.service;

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
import java.time.LocalDateTime;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 소셜 로그인. 카카오·네이버·구글·애플을 한 입구로 처리한다.
 *
 * <p>클라이언트가 제공자 SDK로 로그인해 받은 토큰을 보내면, 서버는 그 토큰을 제공자에게
 * 확인시킨 뒤 <b>우리 토큰</b>을 발급한다. 제공자 토큰은 여기서 버리고 저장하지 않는다.
 *
 * <p><b>이메일로 계정을 합치지 않는다.</b> 사람을 찾는 키는 {@code provider + providerUserId}다.
 * 이메일로 합치면 검증되지 않은 주소를 내세워 남의 계정에 올라탈 수 있고, 애플은
 * privaterelay 주소라 애초에 같은 사람인지 알 수도 없다. 같은 이메일이 이미 있으면
 * 조용히 합치는 대신 충돌로 알리고, 계정 연결은 <b>이미 로그인한 상태에서만</b> 허용한다.
 */
@Slf4j
@Service
public class OAuthLoginService {

  private final Map<OAuthProvider, OAuthVerifier> verifiers = new EnumMap<>(OAuthProvider.class);
  private final AuthIdentityRepository authIdentityRepository;
  private final MemberRepository memberRepository;
  private final ProfileRepository profileRepository;
  private final SubscriptionService subscriptionService;
  private final PasswordEncoder passwordEncoder;
  private final JwtProvider jwtProvider;
  private final JwtProperties jwtProperties;
  private final RefreshTokenService refreshTokenService;

  public OAuthLoginService(
    List<OAuthVerifier> oAuthVerifiers,
    AuthIdentityRepository authIdentityRepository,
    MemberRepository memberRepository,
    ProfileRepository profileRepository,
    SubscriptionService subscriptionService,
    PasswordEncoder passwordEncoder,
    JwtProvider jwtProvider,
    JwtProperties jwtProperties,
    RefreshTokenService refreshTokenService
  ) {
    oAuthVerifiers.forEach(verifier -> this.verifiers.put(verifier.provider(), verifier));
    this.authIdentityRepository = authIdentityRepository;
    this.memberRepository = memberRepository;
    this.profileRepository = profileRepository;
    this.subscriptionService = subscriptionService;
    this.passwordEncoder = passwordEncoder;
    this.jwtProvider = jwtProvider;
    this.jwtProperties = jwtProperties;
    this.refreshTokenService = refreshTokenService;
  }

  @Transactional
  public TokenResponse login(String rawProvider, String providerToken, String deviceId) {
    OAuthProvider provider = parseProvider(rawProvider);
    OAuthVerifier verifier = verifiers.get(provider);
    if (verifier == null) {
      throw new CustomException(ErrorCode.OAUTH_PROVIDER_UNSUPPORTED);
    }

    OAuthUser oAuthUser = verifier.verify(providerToken);

    Member member = authIdentityRepository
      .findByProviderAndProviderUserId(provider, oAuthUser.providerUserId())
      .map(identity -> loadMember(identity.getMemberId()))
      .orElseGet(() -> register(provider, oAuthUser));

    if (member.getStatus() == MemberStatus.SUSPENDED) {
      throw new CustomException(ErrorCode.MEMBER_SUSPENDED);
    }

    LocalDateTime now = LocalDateTime.now();
    member.setLastLoginAt(now);
    member.setLastActivityAt(now);
    member.setLoginCount(member.getLoginCount() == null ? 1 : member.getLoginCount() + 1);

    String accessToken = jwtProvider.createAccessToken(member.getId(), member.getUsername());
    String refreshToken = refreshTokenService.issue(member.getId(), deviceId);
    return new TokenResponse(accessToken, "Bearer", jwtProperties.accessExpMillis(), refreshToken);
  }

  private OAuthProvider parseProvider(String rawProvider) {
    try {
      return OAuthProvider.from(rawProvider);
    } catch (IllegalArgumentException e) {
      throw new CustomException(ErrorCode.OAUTH_PROVIDER_UNSUPPORTED);
    }
  }

  private Member loadMember(String memberId) {
    return memberRepository.findById(memberId)
      .orElseThrow(() -> new CustomException(ErrorCode.MEMBER_NOT_FOUND));
  }

  private Member register(OAuthProvider provider, OAuthUser oAuthUser) {
    // 제공자가 검증한 이메일이 이미 쓰이고 있으면 자동으로 합치지 않고 알린다.
    // 사용자는 원래 쓰던 방법으로 로그인한 뒤 계정 설정에서 연결하면 된다.
    if (oAuthUser.hasTrustedEmail()) {
      authIdentityRepository.findFirstByEmailAndEmailVerifiedTrue(oAuthUser.email())
        .ifPresent(existing -> {
          log.info("이미 가입된 이메일로 신규 소셜 로그인이 시도되었습니다. provider={}", provider);
          throw new CustomException(ErrorCode.OAUTH_EMAIL_CONFLICT);
        });
    }

    Member member = new Member();
    // username은 내부 식별자 역할만 한다. 화면에 보이는 이름은 온보딩에서 정하는 프로필 이름이다.
    member.setUsername(provider.name().toLowerCase() + "_" + oAuthUser.providerUserId());
    // 소셜 계정은 비밀번호 로그인을 쓰지 않는다. 아무도 모르는 값을 넣어 그 경로를 막는다.
    member.setPassword(passwordEncoder.encode(UUID.randomUUID().toString()));
    memberRepository.save(member);

    AuthIdentity identity = new AuthIdentity();
    identity.setMemberId(member.getId());
    identity.setProvider(provider);
    identity.setProviderUserId(oAuthUser.providerUserId());
    identity.setEmail(oAuthUser.email());
    identity.setEmailVerified(oAuthUser.emailVerified());
    authIdentityRepository.save(identity);

    // 가입 즉시 당사자 프로필을 만든다. 이후 조회가 "프로필 없음"을 분기하지 않아도 된다.
    Profile profile = new Profile();
    profile.setMember(member);
    profile.setCharacter(CharacterType.LULU);
    profileRepository.save(profile);

    // 소셜로 들어온 계정도 똑같이 Free로 시작한다.
    subscriptionService.createFreeIfAbsent(member);

    return member;
  }
}
