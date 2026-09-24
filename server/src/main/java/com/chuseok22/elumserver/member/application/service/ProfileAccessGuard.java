package com.chuseok22.elumserver.member.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.link.infrastructure.entity.DeviceLink;
import com.chuseok22.elumserver.link.infrastructure.repository.DeviceLinkRepository;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * "이 요청자가 이 이룸이에 무엇을 할 수 있나"를 한 곳에서 답한다 (다중 보호자 명세 4-2).
 *
 * <p>예전에는 "계정의 첫 프로필"과 "프로필의 주인 = 요청자"를 서비스마다 따로 비교했다. 보호자가 여럿이
 * 되면 주인이 하나가 아니고, 이룸이 휴대폰은 보호자의 첫 이룸이가 아니라 연결된 이룸이를 봐야 한다.
 * 판단이 흩어져 있으면 한 곳만 고쳐져 어긋난다.
 *
 * <p>이룸이 휴대폰이 할 수 없는 동작은 URL 단계({@code SecurityConfig})에서도 막혀 있다. 여기서 한 번 더
 * 막는 것은 URL 규칙이 바뀌어도 서버가 최종 판단하기 위해서다.
 */
@Component
@RequiredArgsConstructor
public class ProfileAccessGuard {

  private final ProfileRepository profileRepository;
  private final ProfileGuardianRepository profileGuardianRepository;
  private final DeviceLinkRepository deviceLinkRepository;

  /** 이룸이 단위 동작. 권한 표의 행이다. */
  public enum ProfileAction {
    /** 이룸이 정보·일과 목록 보기. 연결된 보호자와 그 이룸이의 휴대폰. */
    VIEW,
    /** 이룸이 정보 수정·일과 만들기·일과 순서·연결 암호 발급. 연결된 보호자만. */
    MANAGE
  }

  /** 일과 하나에 하는 동작. 권한 표의 행이다. */
  public enum RoutineAction {
    /** 일과·그림 보기. */
    VIEW(true),
    /** 단계 체크·해제·진행. 누가 만들었든 연결된 사람은 할 수 있다. */
    PROGRESS(true),
    /** 복제 — 원본은 그대로 두고 복제한 사람의 새 일과를 만든다. 명세 표에 없어 정했다. */
    COPY(false),
    /** 승인·수정·삭제·보상 수정·카드 편집. 만든 사람만. */
    EDIT(false);

    private final boolean elumiAllowed;

    RoutineAction(boolean elumiAllowed) {
      this.elumiAllowed = elumiAllowed;
    }

    public boolean elumiAllowed() {
      return elumiAllowed;
    }
  }

  /**
   * 이 요청이 가리키는 이룸이. 이 동작을 할 수 있는지까지 확인한다.
   *
   * <p>헤더가 없으면 가장 먼저 합류한 이룸이다 — 헤더를 모르는 지금 앱이 지금과 같은 이룸이를 본다(E36).
   */
  @Transactional(readOnly = true)
  public Profile profileFor(Caller caller, ProfileAction action) {
    if (caller.isElumi()) {
      if (action == ProfileAction.MANAGE) {
        throw new CustomException(ErrorCode.DEVICE_LINK_FORBIDDEN_FOR_ELUMI);
      }
      String linkedProfileId = linkedProfileId(caller);
      // 이룸이 휴대폰은 연결된 이룸이만 본다 (E28).
      if (caller.profileId() != null && !caller.profileId().equals(linkedProfileId)) {
        throw new CustomException(ErrorCode.PROFILE_ACCESS_DENIED);
      }
      return requireProfile(linkedProfileId);
    }
    if (caller.profileId() != null) {
      // 연결을 먼저 본다 — 없는 이룸이와 남의 이룸이를 같은 403 으로 답해 존재 여부를 흘리지 않는다 (E27).
      requireGuardianOf(caller.memberId(), caller.profileId());
      return requireProfile(caller.profileId());
    }
    return profileRepository.findAllGuardedBy(caller.memberId()).stream()
      .findFirst()
      .orElseThrow(() -> new CustomException(ErrorCode.PROFILE_NOT_FOUND));
  }

  /** 연결된 이룸이 목록. 비어 있을 수 있다 (E29). 이룸이 휴대폰에는 그 연결의 이룸이 하나만 보인다. */
  @Transactional(readOnly = true)
  public List<Profile> profilesOf(Caller caller) {
    if (caller.isElumi()) {
      return List.of(requireProfile(linkedProfileId(caller)));
    }
    return profileRepository.findAllGuardedBy(caller.memberId());
  }

  /** 이 보호자가 이 이룸이에 연결돼 있지 않으면 403. */
  public void requireGuardianOf(String memberId, String profileId) {
    if (!profileGuardianRepository.existsByProfileIdAndMemberId(profileId, memberId)) {
      throw new CustomException(ErrorCode.PROFILE_ACCESS_DENIED);
    }
  }

  /**
   * 일과 하나에 이 동작을 해도 되는가.
   *
   * @param profileId 일과가 속한 이룸이
   * @param createdBy 일과를 만든 보호자. 옛 서버가 만들어 비어 있으면 아무도 고치지 못한다(부팅 때 채운다)
   */
  @Transactional(readOnly = true)
  public void checkRoutine(Caller caller, String profileId, String createdBy, RoutineAction action) {
    if (caller.isElumi()) {
      if (!action.elumiAllowed()) {
        throw new CustomException(ErrorCode.DEVICE_LINK_FORBIDDEN_FOR_ELUMI);
      }
      if (!profileId.equals(linkedProfileId(caller))) {
        throw new CustomException(ErrorCode.ROUTINE_ACCESS_DENIED);
      }
      return;
    }
    if (!profileGuardianRepository.existsByProfileIdAndMemberId(profileId, caller.memberId())) {
      throw new CustomException(ErrorCode.ROUTINE_ACCESS_DENIED);
    }
    if (action == RoutineAction.EDIT && !caller.memberId().equals(createdBy)) {
      throw new CustomException(ErrorCode.ROUTINE_NOT_CREATOR);
    }
  }

  /**
   * 이룸이 휴대폰이 보는 이룸이 = 연결의 {@code profile_id} (명세 4-5).
   *
   * <p>필터가 요청마다 연결이 살아 있는지 이미 봤다. 여기서는 그 연결이 이 토큰의 계정 것인지와
   * 이룸이가 정해져 있는지를 본다. 비어 있으면 보호자의 첫 이룸이로 메우지 않는다 — 그게 바로 고치려는 동작이다.
   */
  private String linkedProfileId(Caller caller) {
    return deviceLinkRepository.findById(caller.linkId())
      .filter(DeviceLink::isLinked)
      .filter(link -> caller.memberId().equals(link.getMemberId()))
      .map(DeviceLink::getProfileId)
      .orElseThrow(() -> new CustomException(ErrorCode.PROFILE_NOT_FOUND));
  }

  private Profile requireProfile(String profileId) {
    return profileRepository.findById(profileId)
      .orElseThrow(() -> new CustomException(ErrorCode.PROFILE_NOT_FOUND));
  }
}
