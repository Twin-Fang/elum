package com.chuseok22.elumserver.member.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.link.core.CodeDigest;
import com.chuseok22.elumserver.link.core.LinkCode;
import com.chuseok22.elumserver.member.application.dto.response.ProfileInviteResponse;
import com.chuseok22.elumserver.member.application.dto.response.ProfileJoinResponse;
import com.chuseok22.elumserver.member.application.dto.response.ProfileSummaryResponse;
import com.chuseok22.elumserver.member.core.GuardianDisplayName;
import com.chuseok22.elumserver.member.infrastructure.entity.GuardianKind;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.entity.ProfileGuardian;
import com.chuseok22.elumserver.member.infrastructure.entity.ProfileInvite;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileInviteRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import java.time.LocalDateTime;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 초대 코드로 보호자가 이룸이에 합류한다 (다중 보호자 명세 4-6, 이슈 #361).
 *
 * <p>연결된 보호자가 여섯 글자를 발급해 불러주면, 다른 보호자가 그것을 넣어 같은 이룸이에 붙는다. 코드의
 * 모양·해시·유효 시간·실패 횟수는 연결 암호와 한 부품({@link LinkCode}, {@link CodeDigest})을 쓴다.
 *
 * <p><b>잠금 순서는 이룸이 행 → 초대 행이다.</b> 나가기(이룸이 행 잠금 → 그 사람의 초대 폐기)와 같은 순서라 서로
 * 교착하지 않는다. 같은 코드를 동시에 넣거나(E3), 합류하는 사이에 마지막 보호자가 나가 이룸이가 지워지는(E5)
 * 경쟁은 모두 이 이룸이 행 잠금 뒤에 줄을 선다.
 *
 * <p>클래스에 읽기 전용 트랜잭션을 걸지 않는다 — 모든 메서드가 쓰기다 (ReadOnlyTransactionWriteTest).
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ProfileInviteService {

  /** 코드가 겹쳤을 때 다시 뽑는 횟수. 7억 가지라 한 번 겹치기도 어렵다 — 끝없이 돌지 않게 상한만 둔다. */
  private static final int MAX_CODE_ATTEMPTS = 5;

  private final ProfileRepository profileRepository;
  private final ProfileGuardianRepository profileGuardianRepository;
  private final ProfileInviteRepository profileInviteRepository;
  private final MemberRepository memberRepository;
  private final ProfileAccessGuard profileAccessGuard;
  private final GuardianshipService guardianshipService;
  private final ProfileInviteRateLimiter rateLimiter;

  /**
   * 초대 코드를 새로 낸다.
   *
   * <p><b>이 사람이 이 이룸이에 낸 이전 미사용 코드는 폐기한다</b> (E9). 남겨 두면 "다시 만들기"를 누른 뒤에도 옛
   * 코드가 통해, 화면에 보이는 것과 실제로 통하는 것이 달라진다. 다른 사람이 낸 코드나 이미 쓰인 코드는 건드리지
   * 않는다.
   *
   * @throws CustomException 이룸이 휴대폰이면 DEVICE_LINK_FORBIDDEN_FOR_ELUMI, 연결되지 않은 이룸이면
   *                         PROFILE_ACCESS_DENIED, 너무 잦으면 PROFILE_INVITE_TOO_MANY_ATTEMPTS
   */
  @Transactional
  public ProfileInviteResponse issue(Caller caller, String profileId) {
    // 이룸이 휴대폰은 발급할 수 없다 (E7). URL 규칙이 먼저 막지만 서버가 최종 판단한다.
    if (caller.isElumi()) {
      throw new CustomException(ErrorCode.DEVICE_LINK_FORBIDDEN_FOR_ELUMI);
    }
    String memberId = caller.memberId();
    if (!rateLimiter.tryIssue(memberId)) {
      throw new CustomException(ErrorCode.PROFILE_INVITE_TOO_MANY_ATTEMPTS);
    }

    // 이룸이 행을 잠근 뒤 연결을 본다 — 그사이 내가 나갔다면(나가기도 이 잠금을 먼저 잡는다) 코드를 낼 수 없다.
    // 없는 이룸이와 남의 이룸이를 같은 403 으로 답해 존재 여부를 흘리지 않는다.
    profileRepository.findByIdForUpdate(profileId)
      .orElseThrow(() -> new CustomException(ErrorCode.PROFILE_ACCESS_DENIED));
    profileAccessGuard.requireGuardianOf(memberId, profileId);

    LocalDateTime now = LocalDateTime.now();
    for (ProfileInvite previous : profileInviteRepository
      .findAllByProfileIdAndIssuedByAndRedeemedAtIsNullAndRevokedAtIsNull(profileId, memberId)) {
      previous.setRevokedAt(now);
    }

    String code = newUniqueCode(now);
    ProfileInvite invite = new ProfileInvite();
    invite.setProfileId(profileId);
    invite.setIssuedBy(memberId);
    invite.setCodeHash(CodeDigest.sha256(code));
    invite.setExpiresAt(now.plus(CodeDigest.CODE_TTL));
    profileInviteRepository.save(invite);

    // 코드 원문은 찍지 않는다. 이 값은 그대로 이룸이 일과를 여는 자격증명이다.
    log.info("초대 코드 발급: memberId={}, profileId={}, expiresAt={}", memberId, profileId, invite.getExpiresAt());
    return new ProfileInviteResponse(code, invite.getExpiresAt(), CodeDigest.CODE_TTL.toSeconds());
  }

  /**
   * 코드를 넣어 이룸이에 합류한다.
   *
   * <p>실패 사유를 잘게 구분해 주지 않는다 — 없는 코드와 이미 쓴 코드는 같은 응답이다. 어떤 코드가 존재했는지가
   * 새어 나가면 추측에 단서가 된다.
   *
   * <p><b>CustomException 에도 롤백하지 않는다.</b> 쓰였거나 폐기된 코드를 두드린 횟수를 실패 응답과 함께 남겨야
   * 하기 때문이다(기본 롤백이면 횟수가 사라진다). 그래서 이 메서드는 <b>실패로 끝나는 길에서는 횟수 말고는 아무것도
   * 쓰지 않는다</b> — 던지기 전에 쓰는 것은 그 횟수(와 5회째 폐기)뿐이고, 합류를 쓰는 구간은 예외를 던지지 않는다.
   *
   * @param rawCode     사용자가 친 코드. 소문자·공백·하이픈은 맞춘다
   * @param displayName 이 이룸이 안에서 불릴 이름(선택)
   */
  @Transactional(noRollbackFor = CustomException.class)
  public ProfileJoinResponse redeem(Caller caller, String rawCode, String displayName) {
    // 이룸이 휴대폰은 합류할 수 없다 (E7). 이룸이 휴대폰의 memberId 는 그 휴대폰을 붙여 준 보호자다.
    if (caller.isElumi()) {
      throw new CustomException(ErrorCode.DEVICE_LINK_FORBIDDEN_FOR_ELUMI);
    }
    String memberId = caller.memberId();
    // 입력 이름은 시도 횟수를 쓰기 전에 거른다 — 잘못된 이름으로 한도를 태우지 않는다.
    String name = GuardianDisplayName.normalize(displayName);

    // 계정당 시도 한도 (E10). 맞든 틀리든 센다.
    if (!rateLimiter.tryRedeem(memberId)) {
      throw new CustomException(ErrorCode.PROFILE_INVITE_TOO_MANY_ATTEMPTS);
    }

    Member member = memberRepository.findById(memberId)
      .filter(m -> m.getStatus() == MemberStatus.ACTIVE)
      .orElseThrow(() -> new CustomException(ErrorCode.MEMBER_NOT_FOUND));
    // 약관 동의를 먼저 받는다 (E6). 동의 없이는 이룸이 정보를 볼 근거가 없다. 온보딩(이룸이 등록)은 건너뛴다.
    if (!member.hasRequiredConsents()) {
      throw new CustomException(ErrorCode.CONSENT_REQUIRED);
    }

    String code = LinkCode.normalize(rawCode);
    if (!LinkCode.hasValidShape(code)) {
      // 모양부터 틀리면 저장소를 뒤지지 않는다.
      throw new CustomException(ErrorCode.PROFILE_INVITE_NOT_FOUND);
    }
    String codeHash = CodeDigest.sha256(code);

    // 1) 이룸이를 먼저 알아낸다. 값만 읽는다 — 잠그기 전의 상태를 영속성 컨텍스트에 남기지 않는다.
    List<String> profileIds = profileInviteRepository.findProfileIdsByCodeHash(codeHash);
    if (profileIds.isEmpty()) {
      throw new CustomException(ErrorCode.PROFILE_INVITE_NOT_FOUND);
    }
    String profileId = profileIds.get(0);

    // 2) 이룸이 행을 잠근다. 같은 코드를 동시에 넣은 사람, 합류하는 사이에 나가는 사람이 여기서 줄을 선다 (E3·E5).
    Profile profile = profileRepository.findByIdForUpdate(profileId).orElse(null);
    if (profile == null) {
      // 입력하는 사이에 마지막 보호자가 나가 이룸이가 지워졌다 (E5). 코드 행도 CASCADE 로 사라졌다.
      throw new CustomException(ErrorCode.PROFILE_INVITE_NOT_FOUND);
    }

    // 3) 잠근 뒤에 코드 행을 새로 읽고 잠근다. 앞사람이 쓴 코드는 여기서 "이미 쓴 코드"로 보인다.
    List<ProfileInvite> rows = profileInviteRepository.findAllByCodeHashAndProfileIdForUpdate(codeHash, profileId);
    LocalDateTime now = LocalDateTime.now();
    ProfileInvite invite = rows.stream().filter(ProfileInvite::isOpen).findFirst()
      .orElse(rows.isEmpty() ? null : rows.get(0));
    if (invite == null) {
      throw new CustomException(ErrorCode.PROFILE_INVITE_NOT_FOUND);
    }

    if (invite.getFailedAttempts() >= CodeDigest.MAX_FAILED_ATTEMPTS) {
      throw new CustomException(ErrorCode.PROFILE_INVITE_TOO_MANY_ATTEMPTS);
    }
    if (!invite.isOpen()) {
      // 이미 쓰였거나 폐기된 코드 — 없는 코드와 같은 응답이다. 두드린 횟수는 남기고 5번째에 막는다 (E8).
      countFailure(invite, now);
      throw new CustomException(ErrorCode.PROFILE_INVITE_NOT_FOUND);
    }
    if (!invite.getExpiresAt().isAfter(now)) {
      throw new CustomException(ErrorCode.PROFILE_INVITE_EXPIRED);
    }
    // 코드를 낸 사람이 아직 이 이룸이를 돌보는가. 나가면 폐기하므로 평소에는 항상 참이다 — 어긋나 있어도
    // 나간 사람의 이름으로 사람이 들어오지 못하게 막는 마지막 안전장치다 (E4).
    if (!profileGuardianRepository.existsByProfileIdAndMemberId(profileId, invite.getIssuedBy())) {
      invite.setRevokedAt(now);
      throw new CustomException(ErrorCode.PROFILE_INVITE_NOT_FOUND);
    }
    // 이미 함께하는 사람(자기가 낸 코드를 자기가 넣은 경우 포함) — 코드는 쓰이지 않고 남는다 (E1·E2).
    if (profileGuardianRepository.existsByProfileIdAndMemberId(profileId, memberId)) {
      throw new CustomException(ErrorCode.PROFILE_ALREADY_GUARDIAN);
    }

    // ── 여기서부터 합류를 쓴다. 예외를 던지는 길이 없다 ──
    ProfileGuardian guardian = new ProfileGuardian();
    guardian.setProfile(profile);
    guardian.setMember(member);
    guardian.setKind(GuardianKind.GUARDIAN);
    guardian.setDisplayName(name);
    guardian.setJoinedAt(now);
    profileGuardianRepository.save(guardian);

    invite.setRedeemedBy(memberId);
    invite.setRedeemedAt(now);

    // 가입 때 생긴 빈 이룸이를 지운다 (명세 4-4, E6).
    List<String> removed = guardianshipService.removeEmptyOwnProfiles(memberId, profileId);

    log.info("초대 코드로 합류: memberId={}, profileId={}, issuedBy={}, 지운 빈 이룸이={}",
      memberId, profileId, invite.getIssuedBy(), removed.size());
    return new ProfileJoinResponse(ProfileSummaryResponse.from(profile), removed);
  }

  /** 우리가 쓸 수 있는 코드 중 겹치지 않는 것을 뽑는다. 같은 해시가 둘이면 입력이 어느 이룸이인지 가릴 수 없다. */
  private String newUniqueCode(LocalDateTime now) {
    for (int attempt = 0; attempt < MAX_CODE_ATTEMPTS; attempt++) {
      String code = LinkCode.generate();
      if (!profileInviteRepository.existsByCodeHashAndRedeemedAtIsNullAndRevokedAtIsNullAndExpiresAtAfter(
        CodeDigest.sha256(code), now)) {
        return code;
      }
    }
    // 7억 가지에서 다섯 번 연속 겹치는 일은 없다. 그래도 무한히 돌지 않고 서버 오류로 끝낸다.
    throw new CustomException(ErrorCode.INTERNAL_SERVER_ERROR);
  }

  private void countFailure(ProfileInvite invite, LocalDateTime now) {
    invite.setFailedAttempts(invite.getFailedAttempts() + 1);
    if (invite.getFailedAttempts() >= CodeDigest.MAX_FAILED_ATTEMPTS && invite.getRevokedAt() == null) {
      invite.setRevokedAt(now);
      log.warn("초대 코드 시도 횟수 초과로 폐기: inviteId={}", invite.getId());
    }
  }
}
