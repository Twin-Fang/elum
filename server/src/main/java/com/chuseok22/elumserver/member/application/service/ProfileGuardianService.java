package com.chuseok22.elumserver.member.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.dto.request.GuardianUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.response.GuardianListResponse;
import com.chuseok22.elumserver.member.application.dto.response.GuardianResponse;
import com.chuseok22.elumserver.member.core.GuardianDisplayName;
import com.chuseok22.elumserver.member.infrastructure.entity.ProfileGuardian;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 이룸이를 함께 돌보는 사람 — 목록 · 내 이름 고치기 · 나가기 (다중 보호자 명세 4-3).
 *
 * <p>모두 <b>연결된 보호자만</b> 부른다. 이룸이 휴대폰은 보지도 나가지도 못한다. 연결되지 않은 이룸이와
 * 없는 이룸이는 같은 403 으로 답한다 — 존재 여부를 흘리지 않는다.
 *
 * <p>나가기 규칙(그 사람 일과·그 사람이 붙인 휴대폰·그 사람이 낸 초대 코드 삭제, 마지막이면 이룸이까지)은
 * {@link GuardianshipService#leave} 가 한다. 여기는 그것을 API 로 연다.
 */
@Service
@RequiredArgsConstructor
public class ProfileGuardianService {

  private final ProfileGuardianRepository profileGuardianRepository;
  private final ProfileAccessGuard profileAccessGuard;
  private final GuardianshipService guardianshipService;

  /**
   * 이 이룸이 안에서 보호자들이 불리는 이름을 한 번에 묻는다. 이름이 없는 사람은 담지 않는다.
   * 다른 도메인(연결)이 repository 를 직접 쓰지 않고 이 메서드로 묻는다.
   */
  @Transactional(readOnly = true)
  public Map<String, String> displayNamesOf(String profileId, Collection<String> memberIds) {
    Map<String, String> names = new HashMap<>();
    if (profileId == null || memberIds == null || memberIds.isEmpty()) {
      return names;
    }
    for (ProfileGuardianRepository.GuardianName g
      : profileGuardianRepository.findNamesByProfileIdAndMemberIdIn(profileId, memberIds)) {
      String name = g.getDisplayName();
      if (name != null && !name.isBlank()) {
        names.put(g.getMemberId(), name.strip());
      }
    }
    return names;
  }

  /**
   * 이 보호자가 접근할 수 있는 이룸이의 현재 이름 한 번에 조회 (profileId > 이름)
   * 연결되지 않았거나 지워진 이룸이는 담지 않는다 (알림 목록이 이름을 흘리지 않게)
   */
  @Transactional(readOnly = true)
  public Map<String, String> profileNamesOf(String memberId, Collection<String> profileIds) {
    Map<String, String> names = new HashMap<>();
    if (memberId == null || profileIds == null || profileIds.isEmpty()) {
      return names;
    }
    for (ProfileGuardianRepository.ProfileName profile
      : profileGuardianRepository.findProfileNamesByMemberIdAndProfileIdIn(memberId, profileIds)) {
      names.put(profile.getProfileId(), profile.getNickname());
    }
    return names;
  }

  /** 이 이룸이를 돌보는 보호자들의 member id, 먼저 합류한 차례 (알림 받는 사람 계산용) */
  @Transactional(readOnly = true)
  public List<String> guardianMemberIdsOf(String profileId) {
    return profileGuardianRepository.findAllByProfileIdOrderByJoinedAtAsc(profileId).stream()
      .map(guardian -> guardian.getMember().getId())
      .toList();
  }

  /** 함께하는 사람 목록, 먼저 합류한 차례. */
  @Transactional(readOnly = true)
  public GuardianListResponse list(Caller caller, String profileId) {
    requireGuardian(caller, profileId);
    List<GuardianResponse> guardians = profileGuardianRepository.findAllByProfileIdOrderByJoinedAtAsc(profileId)
      .stream()
      .map(guardian -> GuardianResponse.from(guardian, caller.memberId()))
      .toList();
    return new GuardianListResponse(guardians);
  }

  /**
   * 내가 이 이룸이에서 불리는 이름·표시를 고친다. 남의 것은 고칠 수 없다 — 대상이 "나"로 고정이다.
   *
   * <p>보낸 항목만 바뀐다. 이름을 빈 문자열로 보내면 지운다. 표시(kind)는 권한과 무관하다.
   */
  @Transactional
  public GuardianResponse updateMe(Caller caller, String profileId, GuardianUpdateRequest request) {
    requireGuardian(caller, profileId);
    if (request == null || (request.kind() == null && request.displayName() == null)) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    ProfileGuardian mine = profileGuardianRepository.findByProfileIdAndMemberId(profileId, caller.memberId())
      .orElseThrow(() -> new CustomException(ErrorCode.PROFILE_ACCESS_DENIED));
    if (request.kind() != null) {
      mine.setKind(request.kind());
    }
    if (request.displayName() != null) {
      mine.setDisplayName(GuardianDisplayName.normalize(request.displayName()));
    }
    return GuardianResponse.from(mine, caller.memberId());
  }

  /**
   * 이 이룸이에서 나간다 — 자기만. 1단계의 나가기 규칙을 그대로 쓴다.
   *
   * <p>도중에 실패하면 전부 되돌린다. 이 호출이 곧 한 트랜잭션이다.
   */
  @Transactional
  public void leave(Caller caller, String profileId) {
    requireGuardian(caller, profileId);
    guardianshipService.leave(caller.memberId(), profileId);
  }

  /** 이룸이 휴대폰이면 403(이룸이 휴대폰 전용 코드), 연결되지 않았으면 PROFILE_ACCESS_DENIED. */
  private void requireGuardian(Caller caller, String profileId) {
    if (caller.isElumi()) {
      throw new CustomException(ErrorCode.DEVICE_LINK_FORBIDDEN_FOR_ELUMI);
    }
    profileAccessGuard.requireGuardianOf(caller.memberId(), profileId);
  }
}
