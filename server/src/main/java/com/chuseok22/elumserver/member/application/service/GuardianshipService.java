package com.chuseok22.elumserver.member.application.service;

import com.chuseok22.elumserver.auth.infrastructure.repository.RefreshTokenRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.link.core.ElumiDeviceId;
import com.chuseok22.elumserver.link.infrastructure.entity.DeviceLink;
import com.chuseok22.elumserver.link.infrastructure.repository.DeviceLinkRepository;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.GuardianKind;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.entity.ProfileGuardian;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.time.LocalDateTime;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 보호자와 이룸이의 관계를 만들고 끊는다 (다중 보호자 명세 4-3).
 *
 * <p>원칙은 하나다 — <b>한 사람이 나가면 자기 것만 지운다.</b> 그래서 탈퇴와 나가기가 서로
 * 부딪치지 않는다. 마지막 보호자가 나가면 돌볼 사람이 없으므로 이룸이도 지운다.
 *
 * <p>클래스에 읽기 전용 트랜잭션을 걸지 않는다 — 모든 메서드가 쓰기다 (ReadOnlyTransactionWriteTest).
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class GuardianshipService {

  private final ProfileRepository profileRepository;
  private final ProfileGuardianRepository profileGuardianRepository;
  private final RoutineRepository routineRepository;
  private final DeviceLinkRepository deviceLinkRepository;
  private final RefreshTokenRepository refreshTokenRepository;

  /**
   * 가입한 사람의 빈 이룸이를 만든다. 온보딩에서 이름·캐릭터를 채운다.
   *
   * <p>가입 때 만들어 두지 않으면 이후 모든 조회가 "이룸이 없음"을 분기해야 한다. 관계 행이 없으면
   * 새 서버는 이 이룸이를 찾지 못한다 — 판단이 관계 표만 보기 때문이다.
   */
  @Transactional
  public Profile createOwnProfile(Member member) {
    Profile profile = new Profile();
    // 옛 서버 호환용 대표 보호자. V23 전까지 계속 채운다 — 되돌리면 옛 코드가 이 값으로 프로필을 찾는다.
    profile.setMember(member);
    profile.setCharacter(CharacterType.LULU);
    profileRepository.save(profile);

    ProfileGuardian guardian = new ProfileGuardian();
    guardian.setProfile(profile);
    guardian.setMember(member);
    guardian.setKind(GuardianKind.GUARDIAN);
    guardian.setJoinedAt(LocalDateTime.now());
    profileGuardianRepository.save(guardian);
    return profile;
  }

  /**
   * 한 이룸이에서 나간다. 2단계의 나가기 API 가 부른다.
   *
   * @throws CustomException 이룸이가 없으면 PROFILE_NOT_FOUND, 연결돼 있지 않으면 PROFILE_ACCESS_DENIED
   */
  @Transactional
  public void leave(String memberId, String profileId) {
    Profile profile = profileRepository.findByIdForUpdate(profileId)
      .orElseThrow(() -> new CustomException(ErrorCode.PROFILE_NOT_FOUND));
    if (!leaveLocked(memberId, profile)) {
      throw new CustomException(ErrorCode.PROFILE_ACCESS_DENIED);
    }
  }

  /**
   * 탈퇴 직전에 연결된 모든 이룸이에서 나간다 (명세 4-3 회원 탈퇴).
   *
   * <p><b>이룸이 id 순서로 잠근다.</b> 두 사람이 같은 두 이룸이를 서로 다른 순서로 잠그면 DB 가 교착으로
   * 한쪽을 죽인다 — 그 사람의 탈퇴가 500 으로 끝난다.
   */
  @Transactional
  public void leaveAll(String memberId) {
    List<String> profileIds = profileGuardianRepository.findProfileIdsByMemberId(memberId).stream()
      .sorted()
      .toList();
    for (String profileId : profileIds) {
      // 동시에 다른 탈퇴가 이 이룸이를 먼저 지웠을 수 있다 — 그러면 나갈 곳이 없을 뿐이다.
      profileRepository.findByIdForUpdate(profileId).ifPresent(profile -> leaveLocked(memberId, profile));
    }

    // 관계 밖에 남은 내 일과는 있어서는 안 된다. 그래도 남아 있으면 created_by 외래키가 보관 기간 뒤
    // 완전 삭제(#372)의 계정 삭제를 막는다 — 구독 표 때 탈퇴가 그렇게 통째로 실패한 채 배포됐다. 치우고 흔적을 남긴다.
    List<Routine> stray = routineRepository.findAllByCreatedBy(memberId);
    if (!stray.isEmpty()) {
      log.warn("관계 밖에 남은 일과를 지웁니다: memberId={}, count={}", memberId, stray.size());
      routineRepository.deleteAll(stray);
    }
  }

  /**
   * 잠근 이룸이에서 나간다. 연결돼 있지 않으면 아무것도 하지 않고 false.
   *
   * <p>별은 건드리지 않는다 — 이룸이가 해낸 것이라 일과가 사라져도 남는다 (E22). 그림 파일도 지우지
   * 않는다 — 복제한 일과가 같은 파일을 가리켜, 지우면 다른 보호자의 일과 그림이 깨진다.
   */
  private boolean leaveLocked(String memberId, Profile profile) {
    String profileId = profile.getId();
    ProfileGuardian mine = profileGuardianRepository.findByProfileIdAndMemberId(profileId, memberId).orElse(null);
    if (mine == null) {
      return false;
    }
    LocalDateTime now = LocalDateTime.now();

    // 내가 만든 이 이룸이의 일과 — 승인 전(임시저장)도 함께 (E12). 단계는 cascade 로 함께 지워진다.
    // 이룸이가 지금 수행 중이면 이룸이 휴대폰의 다음 요청이 404 를 받는다 (E11).
    routineRepository.deleteAll(routineRepository.findAllByProfileIdAndCreatedBy(profileId, memberId));

    // 내가 붙인 이 이룸이의 휴대폰 — 연결을 끊고 그 기기 세션을 폐기한다 (E13). 남은 보호자가 다시 붙인다.
    List<DeviceLink> myPhones = deviceLinkRepository.findAllByMemberIdAndProfileId(memberId, profileId);
    for (DeviceLink phone : myPhones) {
      if (phone.getRevokedAt() == null) {
        phone.setRevokedAt(now);
      }
    }
    revokePhoneSessions(myPhones, now);
    // 이 사람이 발급한 초대 코드(E4)는 발급 경로가 생기는 2단계에서 여기서 폐기한다. 지금은 발급할 길이 없고,
    // 이룸이를 지우면 표의 CASCADE 가 남은 코드를 치운다 (V22).

    profileGuardianRepository.delete(mine);

    // 방금 지운 관계가 조회에 섞여 와도(flush 전) 세지 않는다.
    List<ProfileGuardian> remaining = profileGuardianRepository.findAllByProfileIdOrderByJoinedAtAsc(profileId)
      .stream()
      .filter(guardian -> !memberId.equals(guardian.getMember().getId()))
      .toList();
    if (remaining.isEmpty()) {
      removeProfile(profile, now);
    } else {
      // 대표 보호자(옛 서버 호환)는 늘 "가장 먼저 합류한 사람"이다 (E14). 나간 사람이 대표였다면 여기서
      // 바뀌고, 아니었다면 같은 값이라 UPDATE 가 나가지 않는다. 안 바꾸면 탈퇴 때 profile.member_id 가
      // 지워질 계정을 가리켜 외래키에 걸린다.
      profile.setMember(remaining.get(0).getMember());
    }
    log.info("이룸이에서 나갔습니다: memberId={}, profileId={}, 남은 보호자={}", memberId, profileId, remaining.size());
    return true;
  }

  /** 마지막 보호자가 나갔다. 돌볼 사람이 없으므로 이룸이를 지운다 (명세 4-3). */
  private void removeProfile(Profile profile, LocalDateTime now) {
    String profileId = profile.getId();
    // 옛 서버로 되돌린 동안 created_by 없이 생긴 일과까지 — 남으면 프로필을 지울 수 없다.
    routineRepository.deleteAll(routineRepository.findAllByProfileId(profileId));
    List<DeviceLink> phones = deviceLinkRepository.findAllByProfileId(profileId);
    revokePhoneSessions(phones, now);
    deviceLinkRepository.deleteAll(phones);
    profileRepository.delete(profile);
  }

  /** 연결된 휴대폰의 리프레시 토큰을 기기 단위로 끊는다. 보호자 세션은 건드리지 않는다. */
  private void revokePhoneSessions(List<DeviceLink> phones, LocalDateTime now) {
    for (DeviceLink phone : phones) {
      if (phone.getRedeemedAt() == null) {
        continue;
      }
      // 연결할 때 서버가 넣으므로 비어 있을 수 없지만, 비었으면 규칙대로 만든다 (DeviceLinkService.revoke 와 같다).
      String deviceId = phone.getLinkedDeviceId() != null
        ? phone.getLinkedDeviceId() : ElumiDeviceId.of(phone.getId());
      refreshTokenRepository.revokeByMemberIdAndDeviceId(phone.getMemberId(), deviceId, now);
    }
  }
}
