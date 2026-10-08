package com.chuseok22.elumserver.link.application.service;

import com.chuseok22.elumserver.auth.application.dto.response.TokenResponse;
import com.chuseok22.elumserver.auth.application.service.RefreshTokenService;
import com.chuseok22.elumserver.auth.infrastructure.entity.RevokeReason;
import com.chuseok22.elumserver.auth.infrastructure.repository.RefreshTokenRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import com.chuseok22.elumserver.common.infrastructure.properties.JwtProperties;
import com.chuseok22.elumserver.link.application.dto.response.LinkCodeResponse;
import com.chuseok22.elumserver.link.application.dto.response.LinkStatusResponse;
import com.chuseok22.elumserver.link.application.dto.response.LinkedDeviceResponse;
import com.chuseok22.elumserver.link.core.CodeDigest;
import com.chuseok22.elumserver.link.core.ElumiDeviceId;
import com.chuseok22.elumserver.link.core.LinkCode;
import com.chuseok22.elumserver.common.infrastructure.jwt.LinkRole;
import com.chuseok22.elumserver.link.infrastructure.entity.DeviceLink;
import com.chuseok22.elumserver.link.infrastructure.repository.DeviceLinkRepository;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.stream.Stream;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 이룸이 휴대폰 연결.
 *
 * <p>보호자가 여섯 글자를 발급받아 불러주고, 이룸이 휴대폰이 그것을 넣으면 같은 계정에
 * {@code ELUMI} 역할로 붙는다. QR을 쓰지 않는다 — 카메라 권한·촬영 흐름까지 만들 여력이 없다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class DeviceLinkService {

  /** 불러주고 받아적는 시간. 초대 코드와 같은 값을 쓴다 ({@link CodeDigest}). */
  public static final Duration CODE_TTL = CodeDigest.CODE_TTL;

  /**
   * 한 암호에 허용하는 실패 횟수.
   *
   * <p>redeem은 인증 없이 열려 있어 온라인 추측이 가능하다. 30자 6자리가 7억 가지라도
   * 횟수를 세지 않으면 두드릴 수 있고, 뚫리면 남의 가정 당사자의 일과가 그대로 보인다.
   * 사람이 받아적다 틀리는 횟수로는 5회면 넉넉하다.
   */
  public static final int MAX_FAILED_ATTEMPTS = CodeDigest.MAX_FAILED_ATTEMPTS;

  private final DeviceLinkRepository deviceLinkRepository;
  private final MemberRepository memberRepository;
  private final ProfileAccessGuard profileAccessGuard;
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
  public LinkCodeResponse issue(Caller caller) {
    String memberId = caller.memberId();
    Member member = requireMember(memberId);
    // 이 휴대폰이 볼 이룸이 — 보호자가 짚은(헤더) 또는 가장 먼저 연결된 이룸이. 연결 안 된 이룸이면 403.
    // 이 값이 곧 이룸이 휴대폰의 이룸이다 (명세 4-5). 보호자의 "첫 이룸이"로 뒤에서 다시 찾지 않는다.
    String profileId = profileAccessGuard.profileFor(caller, ProfileAction.MANAGE).getId();
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
    link.setProfileId(profileId);
    link.setCodeHash(hash(code));
    link.setExpiresAt(now.plus(CODE_TTL));
    deviceLinkRepository.save(link);

    // 암호 원문은 찍지 않는다. 이 값은 그대로 계정에 붙는 자격증명이다.
    log.info("연결 암호 발급: memberId={}, expiresAt={}", memberId, link.getExpiresAt());
    return new LinkCodeResponse(code, link.getExpiresAt(), CODE_TTL.toSeconds());
  }

  /**
   * 보호자 설정 화면이 보여줄 상태.
   *
   * <p>휴대폰은 <b>여러 대 붙을 수 있다.</b> 태블릿과 휴대폰을 함께 쓰는 경우가 있고,
   * 한 대만 허용하면 새 기기를 붙이는 순간 쓰던 기기가 조용히 끊긴다.
   *
   * <p><b>이룸이 기준으로 보여 준다</b>. 연결된 보호자는 모두 동등해서, 다른 보호자가 붙인
   * 휴대폰도 보여야 끊을 수 있다. 연결 ID(`profile_id`)가 비어 있는 옛 행만 붙인 사람 기준으로 남긴다.
   * 아직 안 쓴 암호(발급 중)는 **내가 발급한 것만** 보인다 — 남이 발급한 암호의 만료까지 내 화면에 올릴 이유가 없다.
   */
  @Transactional(readOnly = true)
  public LinkStatusResponse status(Caller caller) {
    LocalDateTime now = LocalDateTime.now();
    List<DeviceLink> alive = aliveLinksVisibleTo(caller);

    List<LinkedDeviceResponse> devices = alive.stream()
      .filter(DeviceLink::isLinked)
      .map(l -> new LinkedDeviceResponse(l.getId(), l.getRedeemedAt()))
      .toList();

    LocalDateTime pending = alive.stream()
      .filter(l -> l.getMemberId().equals(caller.memberId()))
      .filter(l -> l.isRedeemable(now))
      .map(DeviceLink::getExpiresAt)
      .findFirst()
      .orElse(null);

    return new LinkStatusResponse(devices, pending);
  }

  /** 이 보호자가 보는 살아 있는 연결 — 이룸이의 것 + 이룸이가 비어 있는 옛 행 중 내 것. 최신이 앞에 온다. */
  private List<DeviceLink> aliveLinksVisibleTo(Caller caller) {
    List<DeviceLink> own = deviceLinkRepository
      .findByMemberIdAndRevokedAtIsNullOrderByCreatedAtDesc(caller.memberId()).stream()
      .filter(l -> l.getProfileId() == null)
      .toList();
    // 예외를 잡아 넘기지 않는다 — 판단자의 예외가 이 트랜잭션을 rollback-only 로 만들어 커밋에서
    // UnexpectedRollbackException 이 난다. 이룸이가 없는 보호자(E29)는 목록이 비어 오는 쪽을 쓴다.
    Optional<String> profileId = caller.profileId() != null
      ? Optional.of(profileAccessGuard.profileFor(caller, ProfileAction.MANAGE).getId())
      : profileAccessGuard.profilesOf(caller).stream().findFirst().map(Profile::getId);
    List<DeviceLink> ofProfile = profileId
      .map(deviceLinkRepository::findByProfileIdAndRevokedAtIsNullOrderByCreatedAtDesc)
      .orElse(List.of());
    return Stream.concat(ofProfile.stream(), own.stream())
      .sorted(Comparator.comparing(DeviceLink::getCreatedAt, Comparator.nullsLast(Comparator.reverseOrder())))
      .toList();
  }

  /**
   * 이룸이 휴대폰이 암호를 넣는다. <b>인증 없이 불린다.</b>
   *
   * <p>실패 사유를 잘게 구분해 주지 않는다 — 없는 암호와 이미 쓴 암호를 구분해 주면
   * 어떤 값이 존재했는지가 새어 나가 추측에 단서가 된다.
   */
  @Transactional
  public TokenResponse redeem(String rawCode) {
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
    // 기기 값은 서버가 만든다. 갱신이 이 값으로 이룸이 휴대폰임을 알아본다.
    String deviceId = ElumiDeviceId.of(link.getId());
    link.setRedeemedAt(now);
    link.setLinkedDeviceId(deviceId);

    String accessToken = jwtProvider.createAccessToken(
      member.getId(), member.getUsername(), LinkRole.ELUMI, link.getId());
    String refreshToken = refreshTokenService.issue(member.getId(), deviceId);

    log.info("이룸이 휴대폰 연결됨: memberId={}, deviceId={}", member.getId(), deviceId);
    return new TokenResponse(accessToken, "Bearer", jwtProperties.accessExpMillis(), refreshToken);
  }

  /**
   * 보호자가 연결 하나를 끊는다 (§8-5).
   *
   * <p>이룸이 휴대폰이 손에 없을 때(잃어버림·기기 교체·남의 폰에 잘못 연결) 보호자가
   * 끊을 길이 없으면 그 폰이 계속 일과를 본다.
   *
   * <p>여러 대가 붙어 있을 수 있으므로 <b>어느 연결인지 짚어서</b> 끊는다.
   *
   * <p><b>그 이룸이를 함께 돌보는 보호자는 누구나 끊는다</b>. 붙인 사람에게 묶는 것은
   * 토큰의 주인(`sub`)뿐이라 세션은 붙인 보호자의 것을 폐기한다. 돌보지 않는 사람에게는 연결이 있는지조차
   * 알리지 않으려고 없는 연결과 같은 404 로 답한다.
   */
  @Transactional
  public void revoke(String memberId, String linkId) {
    DeviceLink link = deviceLinkRepository.findById(linkId)
      .filter(DeviceLink::isLinked)
      .filter(l -> mayManage(memberId, l))
      .orElseThrow(() -> new CustomException(ErrorCode.DEVICE_LINK_NOT_CONNECTED));

    terminate(link);
  }

  /**
   * 이룸이 휴대폰이 <b>자기</b> 연결을 끊는다. 설정의 로그아웃·회원 탈퇴가 부른다.
   *
   * <p>리프레시 토큰만 끊고 연결을 두면 보호자 설정에 계속
   * `연결됨`으로 남으므로 연결도 끊는다. 어느 연결인지는 토큰의 `linkId` 가 정한다 — 요청이 짚지 않는다. 그래서 남의 연결을
   * 끊을 길이 없고, 이미 끊긴 연결은 404 라 앱이 "이미 끊김"으로 받아들일 수 있다.
   */
  @Transactional
  public void revokeCurrent(Caller caller) {
    if (!caller.isElumi()) {
      throw new CustomException(ErrorCode.DEVICE_LINK_ONLY_FOR_ELUMI);
    }
    DeviceLink link = deviceLinkRepository.findById(caller.linkId())
      .filter(DeviceLink::isLinked)
      .filter(l -> l.getMemberId().equals(caller.memberId()))
      .orElseThrow(() -> new CustomException(ErrorCode.DEVICE_LINK_NOT_CONNECTED));

    terminate(link);
  }

  /** 이 보호자가 이 연결을 끊어도 되는가 — 그 이룸이를 돌보는 사람. 이룸이가 비어 있는 옛 행은 붙인 사람만. */
  private boolean mayManage(String memberId, DeviceLink link) {
    if (link.getProfileId() == null) {
      return link.getMemberId().equals(memberId);
    }
    return profileAccessGuard.isGuardianOf(memberId, link.getProfileId());
  }

  /** 연결을 끊고 그 기기의 세션만 폐기한다. 세션의 주인은 붙인 보호자(`link.memberId`)다. */
  private void terminate(DeviceLink link) {
    LocalDateTime now = LocalDateTime.now();
    link.setRevokedAt(now);

    // 기기를 짚어서 끊는다. 계정 전체를 끊으면 보호자까지 로그아웃된다.
    // linkedDeviceId 는 연결할 때 서버가 넣으므로 비어 있을 수 없다.
    String deviceId = link.getLinkedDeviceId() != null
      ? link.getLinkedDeviceId() : ElumiDeviceId.of(link.getId());
    int killed = refreshTokenRepository.revokeByMemberIdAndDeviceId(
      link.getMemberId(), deviceId, now, RevokeReason.DEVICE_UNLINKED);
    log.info("이룸이 휴대폰 연결 끊음: memberId={}, deviceId={}, 끊은 세션={}",
      link.getMemberId(), deviceId, killed);
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

  /** 해시 규칙은 초대 코드와 함께 쓴다 ({@link CodeDigest}). */
  private String hash(String raw) {
    return CodeDigest.sha256(raw);
  }
}
