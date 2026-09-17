package com.chuseok22.elumserver.link.application.service;

import com.chuseok22.elumserver.auth.application.dto.response.TokenResponse;
import com.chuseok22.elumserver.auth.application.service.RefreshTokenService;
import com.chuseok22.elumserver.auth.infrastructure.repository.RefreshTokenRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import com.chuseok22.elumserver.common.infrastructure.properties.JwtProperties;
import com.chuseok22.elumserver.link.application.dto.response.LinkCodeResponse;
import com.chuseok22.elumserver.link.application.dto.response.LinkStatusResponse;
import com.chuseok22.elumserver.link.core.LinkCode;
import com.chuseok22.elumserver.link.core.LinkRole;
import com.chuseok22.elumserver.link.infrastructure.entity.DeviceLink;
import com.chuseok22.elumserver.link.infrastructure.repository.DeviceLinkRepository;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.HexFormat;
import java.util.List;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 이룸이 휴대폰 연결 (이슈 #200).
 *
 * <p>보호자가 여섯 글자를 발급받아 불러주고, 이룸이 휴대폰이 그것을 넣으면 같은 계정에
 * {@code ELUMI} 역할로 붙는다. QR을 쓰지 않는다 — 카메라 권한·촬영 흐름까지 만들 여력이 없다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class DeviceLinkService {

  /** 불러주고 받아적는 시간. 카운트다운으로 쫓지 않되 하루 종일 살아 있지도 않게. */
  public static final Duration CODE_TTL = Duration.ofMinutes(10);

  /**
   * 한 암호에 허용하는 실패 횟수.
   *
   * <p>redeem은 인증 없이 열려 있어 온라인 추측이 가능하다. 30자 6자리가 7억 가지라도
   * 횟수를 세지 않으면 두드릴 수 있고, 뚫리면 남의 가정 당사자의 일과가 그대로 보인다.
   * 사람이 받아적다 틀리는 횟수로는 5회면 넉넉하다.
   */
  public static final int MAX_FAILED_ATTEMPTS = 5;

  private final DeviceLinkRepository deviceLinkRepository;
  private final MemberRepository memberRepository;
  private final ProfileRepository profileRepository;
  private final RefreshTokenRepository refreshTokenRepository;
  private final RefreshTokenService refreshTokenService;
  private final JwtProvider jwtProvider;
  private final JwtProperties jwtProperties;

  /**
   * 새 연결 암호를 만든다.
   *
   * <p><b>이전에 발급했던 미사용 암호는 폐기한다.</b> 남겨 두면 보호자가 "다시 만들기"를
   * 누른 뒤에도 옛 암호가 통해, 화면에 보이는 것과 실제로 통하는 것이 달라진다.
   * 이미 연결된 것은 건드리지 않는다 — 새 암호를 만드는 것과 기존 연결을 끊는 것은 다른 일이다.
   */
  @Transactional
  public LinkCodeResponse issue(String memberId) {
    Member member = requireMember(memberId);
    LocalDateTime now = LocalDateTime.now();

    for (DeviceLink alive : deviceLinkRepository
      .findByMemberIdAndRevokedAtIsNullOrderByCreatedAtDesc(memberId)) {
      if (alive.getRedeemedAt() == null) {
        alive.setRevokedAt(now);
      }
    }

    String code = LinkCode.generate();
    DeviceLink link = new DeviceLink();
    link.setMemberId(member.getId());
    link.setProfileId(profileRepository.findFirstByMemberIdOrderByCreatedAtAsc(memberId)
      .map(Profile::getId).orElse(null));
    link.setCodeHash(hash(code));
    link.setExpiresAt(now.plus(CODE_TTL));
    deviceLinkRepository.save(link);

    // 암호 원문은 찍지 않는다. 이 값은 그대로 계정에 붙는 자격증명이다.
    log.info("연결 암호 발급: memberId={}, expiresAt={}", memberId, link.getExpiresAt());
    return new LinkCodeResponse(code, link.getExpiresAt(), CODE_TTL.toSeconds());
  }

  /** 보호자 설정 화면이 보여줄 상태. */
  @Transactional(readOnly = true)
  public LinkStatusResponse status(String memberId) {
    LocalDateTime now = LocalDateTime.now();
    List<DeviceLink> alive = deviceLinkRepository
      .findByMemberIdAndRevokedAtIsNullOrderByCreatedAtDesc(memberId);

    Optional<DeviceLink> linked = alive.stream().filter(DeviceLink::isLinked).findFirst();
    if (linked.isPresent()) {
      return new LinkStatusResponse(LinkStatusResponse.STATE_LINKED,
        linked.get().getRedeemedAt(), null);
    }

    Optional<DeviceLink> pending = alive.stream()
      .filter(l -> l.isRedeemable(now)).findFirst();
    return pending
      .map(l -> new LinkStatusResponse(LinkStatusResponse.STATE_PENDING, null, l.getExpiresAt()))
      .orElseGet(() -> new LinkStatusResponse(LinkStatusResponse.STATE_NONE, null, null));
  }

  /**
   * 이룸이 휴대폰이 암호를 넣는다. <b>인증 없이 불린다.</b>
   *
   * <p>실패 사유를 잘게 구분해 주지 않는다 — 없는 암호와 이미 쓴 암호를 구분해 주면
   * 어떤 값이 존재했는지가 새어 나가 추측에 단서가 된다.
   */
  @Transactional
  public TokenResponse redeem(String rawCode, String deviceId) {
    String code = LinkCode.normalize(rawCode);
    if (!LinkCode.hasValidShape(code)) {
      // 모양부터 틀리면 저장소를 뒤지지 않는다 — 없는 값으로 시도 횟수를 늘릴 이유가 없다.
      throw new CustomException(ErrorCode.DEVICE_LINK_NOT_FOUND);
    }

    DeviceLink link = deviceLinkRepository.findByCodeHash(hash(code))
      .orElseThrow(() -> new CustomException(ErrorCode.DEVICE_LINK_NOT_FOUND));

    LocalDateTime now = LocalDateTime.now();

    if (link.getFailedAttempts() >= MAX_FAILED_ATTEMPTS) {
      throw new CustomException(ErrorCode.DEVICE_LINK_TOO_MANY_ATTEMPTS);
    }
    if (link.getRedeemedAt() != null || link.getRevokedAt() != null) {
      countFailure(link, now);
      throw new CustomException(ErrorCode.DEVICE_LINK_NOT_FOUND);
    }
    if (!link.getExpiresAt().isAfter(now)) {
      throw new CustomException(ErrorCode.DEVICE_LINK_EXPIRED);
    }

    Member member = requireMember(link.getMemberId());
    link.setRedeemedAt(now);
    link.setLinkedDeviceId(deviceId);

    String accessToken = jwtProvider.createAccessToken(
      member.getId(), member.getUsername(), LinkRole.ELUMI);
    String refreshToken = refreshTokenService.issue(member.getId(), deviceId);

    log.info("이룸이 휴대폰 연결됨: memberId={}, deviceId={}", member.getId(), deviceId);
    return new TokenResponse(accessToken, "Bearer", jwtProperties.accessExpMillis(), refreshToken);
  }

  /**
   * 보호자가 연결을 끊는다 (§8-5).
   *
   * <p>이룸이 휴대폰이 손에 없을 때(잃어버림·기기 교체·남의 폰에 잘못 연결) 보호자가
   * 끊을 길이 없으면 그 폰이 계속 일과를 본다.
   */
  @Transactional
  public void revoke(String memberId) {
    LocalDateTime now = LocalDateTime.now();
    DeviceLink link = deviceLinkRepository
      .findByMemberIdAndRevokedAtIsNullOrderByCreatedAtDesc(memberId).stream()
      .filter(DeviceLink::isLinked)
      .findFirst()
      .orElseThrow(() -> new CustomException(ErrorCode.DEVICE_LINK_NOT_CONNECTED));

    link.setRevokedAt(now);

    // 기기를 짚어서 끊는다. 계정 전체를 끊으면 보호자까지 로그아웃된다.
    int killed = link.getLinkedDeviceId() == null ? 0
      : refreshTokenRepository.revokeByMemberIdAndDeviceId(memberId, link.getLinkedDeviceId(), now);
    log.info("이룸이 휴대폰 연결 끊음: memberId={}, deviceId={}, 끊은 세션={}",
      memberId, link.getLinkedDeviceId(), killed);
  }

  private void countFailure(DeviceLink link, LocalDateTime now) {
    link.setFailedAttempts(link.getFailedAttempts() + 1);
    if (link.getFailedAttempts() >= MAX_FAILED_ATTEMPTS) {
      link.setRevokedAt(now);
      log.warn("연결 암호 시도 횟수 초과로 폐기: linkId={}", link.getId());
    }
  }

  private Member requireMember(String memberId) {
    return memberRepository.findById(memberId)
      .orElseThrow(() -> new CustomException(ErrorCode.MEMBER_NOT_FOUND));
  }

  /** refresh_token과 같은 방식. 원문은 어디에도 남기지 않는다. */
  private String hash(String raw) {
    try {
      MessageDigest digest = MessageDigest.getInstance("SHA-256");
      return HexFormat.of().formatHex(digest.digest(raw.getBytes(StandardCharsets.UTF_8)));
    } catch (NoSuchAlgorithmException e) {
      throw new IllegalStateException("SHA-256을 쓸 수 없습니다", e);
    }
  }
}
