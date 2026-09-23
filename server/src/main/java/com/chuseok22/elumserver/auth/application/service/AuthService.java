package com.chuseok22.elumserver.auth.application.service;

import com.chuseok22.elumserver.auth.application.dto.request.LoginRequest;
import com.chuseok22.elumserver.auth.application.dto.request.SignUpRequest;
import com.chuseok22.elumserver.auth.application.dto.response.TokenResponse;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import com.chuseok22.elumserver.common.infrastructure.properties.JwtProperties;
import com.chuseok22.elumserver.license.application.service.SubscriptionService;
import com.chuseok22.elumserver.link.core.LinkRole;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AuthService {

  private final MemberRepository memberRepository;

  private final ProfileRepository profileRepository;
  private final PasswordEncoder passwordEncoder;
  private final AuthenticationManager memberAuthenticationManager;
  private final JwtProvider jwtProvider;
  private final JwtProperties jwtProperties;
  private final RefreshTokenService refreshTokenService;
  private final SubscriptionService subscriptionService;

  @Transactional
  public void signUp(SignUpRequest request) {
    if (memberRepository.existsByUsername(request.username())) {
      throw new CustomException(ErrorCode.DUPLICATE_USERNAME);
    }

    Member member = new Member();
    member.setUsername(request.username());
    member.setPassword(passwordEncoder.encode(request.password()));
    memberRepository.save(member);

    // 계정과 함께 당사자 프로필을 만든다. 온보딩에서 이름·캐릭터를 채운다.
    // 가입 시점에 만들어 두지 않으면 이후 모든 조회가 "프로필 없음"을 분기해야 한다.
    Profile profile = new Profile();
    profile.setMember(member);
    profile.setCharacter(CharacterType.LULU);
    profileRepository.save(profile);

    // 로그인하는 사람은 일단 Free다. 행이 없어도 Free로 보긴 하지만, 만들어 두면
    // 관리자 화면에서 모든 계정의 구독이 같은 모양으로 보이고 시작 시점도 남는다.
    subscriptionService.createFreeIfAbsent(member);
  }

  // 로그인 이력(lastLoginAt·loginCount)을 저장해야 하므로 트랜잭션이 필요하다.
  @Transactional
  public TokenResponse login(LoginRequest request, String deviceId) {
    try {
      memberAuthenticationManager.authenticate(
        new UsernamePasswordAuthenticationToken(request.username(), request.password())
      );
    } catch (BadCredentialsException e) {
      throw new CustomException(ErrorCode.INVALID_CREDENTIALS);
    }

    Member member = memberRepository.findByUsername(request.username())
      .orElseThrow(() -> new CustomException(ErrorCode.MEMBER_NOT_FOUND));

    // 정지 계정은 비밀번호가 맞아도 로그인 자체를 차단한다.
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

  /**
   * 리프레시 토큰으로 액세스 토큰을 다시 발급한다.
   *
   * <p>회전 방식이라 리프레시 토큰도 함께 새로 나간다. 클라이언트는 응답의 새 값으로
   * 저장된 값을 덮어써야 한다. 이전 값을 다시 보내면 탈취로 간주돼 세션이 전부 끊긴다.
   */
  @Transactional
  public TokenResponse refresh(String refreshToken, String deviceId) {
    RefreshTokenService.RotationResult rotation = refreshTokenService.rotate(refreshToken, deviceId);

    Member member = memberRepository.findById(rotation.memberId())
      .orElseThrow(() -> new CustomException(ErrorCode.MEMBER_NOT_FOUND));

    // 갱신은 로그인만큼 자주 일어난다. 정지된 계정이 갱신으로 계속 살아 있지 않도록
    // 여기서도 상태를 확인하고, 걸리면 남은 세션까지 끊는다.
    if (member.getStatus() == MemberStatus.SUSPENDED) {
      refreshTokenService.revokeAll(member.getId());
      throw new CustomException(ErrorCode.MEMBER_SUSPENDED);
    }

    member.setLastActivityAt(LocalDateTime.now());

    // 이룸이 휴대폰 세션이면 역할과 연결을 그대로 이어 준다 (이슈 #359).
    // 역할 없는 발급은 보호자 토큰이라, 그대로 쓰면 갱신 한 번에 이룸이 휴대폰이 보호자 권한을 얻고
    // linkId 도 빠져 연결을 끊어도 막히지 않는다.
    String accessToken = rotation.linkId() != null
      ? jwtProvider.createAccessToken(member.getId(), member.getUsername(), LinkRole.ELUMI, rotation.linkId())
      : jwtProvider.createAccessToken(member.getId(), member.getUsername());
    return new TokenResponse(accessToken, "Bearer", jwtProperties.accessExpMillis(), rotation.refreshToken());
  }

  /**
   * 로그아웃. 해당 계정의 리프레시 토큰을 모두 끊는다.
   *
   * <p>액세스 토큰은 만료 전까지 살아 있다. 무효화하려면 서버가 모든 요청마다 DB를
   * 확인해야 해서 stateless의 이점이 사라진다. 그 대신 액세스를 짧게 두고,
   * 클라이언트가 저장된 토큰을 지우는 것으로 처리한다.
   */
  @Transactional
  public void logout(String refreshToken) {
    refreshTokenService.revokeByToken(refreshToken);
  }
}
