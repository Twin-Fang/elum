package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineGroupResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineGroup;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineGroupRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 일과관리 묶음: 목록, 만들기, 이름·구성 바꾸기, 풀기, 복사하기, 묶음째 보내기 (#806)
 * 권한 = 이 이룸이의 보호자(이룸이 휴대폰 불가). 없는 묶음과 남의 이룸이 묶음은 같은 404
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RoutineGroupService {

  /// 묶음 이름 최대 길이. 일과관리 폴더 아이콘 아래 한 줄
  static final int GROUP_NAME_MAX_LENGTH = 12;

  private final RoutineGroupRepository routineGroupRepository;
  private final RoutineRepository routineRepository;
  private final ProfileAccessGuard profileAccessGuard;
  private final RoutineLibraryService routineLibraryService;
  private final RoutineGroupMembership routineGroupMembership;

  /**
   * 묶음 목록: 이룸이(헤더) > 묶음 순서대로 > 구성원 한 번에 조회 > 2개 미만으로 줄어든 묶음은 뺌
   * 일과가 다른 경로(보호자 나가기 등)로 지워져 줄어든 묶음은 목록에서만 빠짐 — 조회라 쓰지 않음
   */
  public List<RoutineGroupResponse> getGroups(Caller caller) {
    Profile profile = profileAccessGuard.profileFor(caller, ProfileAction.VIEW);
    List<RoutineGroup> groups = routineGroupRepository.findAllByProfileIdOrderByDisplayOrderAscCreatedAtAsc(profile.getId());
    if (groups.isEmpty()) {
      return List.of();
    }
    Map<String, List<String>> routineIdsByGroupId = routineRepository
      .findAllByGroupIdInOrderByGroupOrderAsc(groups.stream().map(RoutineGroup::getId).toList())
      .stream()
      .collect(Collectors.groupingBy(Routine::getGroupId, LinkedHashMap::new,
        Collectors.mapping(Routine::getId, Collectors.toList())));
    return groups.stream()
      .filter(group -> routineIdsByGroupId.getOrDefault(group.getId(), List.of()).size()
        >= RoutineGroupMembership.GROUP_MIN_ROUTINE_COUNT)
      .map(group -> RoutineGroupResponse.of(group, routineIdsByGroupId.get(group.getId())))
      .toList();
  }

  /**
   * 묶음 만들기: 이룸이(헤더, 보호자만) > 이름 검증 > 구성원 검증 > 저장(칸 자리 = 구성원 중 가장 앞 칸, 없으면 맨 뒤) > 구성원 넣기(다른 묶음에서 옮김)
   */
  @Transactional
  public RoutineGroupResponse create(Caller caller, String name, List<String> routineIds) {
    Profile profile = profileAccessGuard.profileFor(caller, ProfileAction.MANAGE);
    String trimmedName = validateName(name);
    List<Routine> members = loadMembers(profile.getId(), routineIds);
    int displayOrder = members.stream().map(Routine::getLibraryOrder).filter(Objects::nonNull)
      .min(Integer::compare).orElseGet(() -> nextLibraryOrder(profile.getId()));
    RoutineGroup group = routineGroupRepository.save(newGroup(profile, caller.memberId(), trimmedName, displayOrder));
    routineGroupMembership.assign(group.getId(), members);
    return RoutineGroupResponse.of(group, idsOf(members));
  }

  /// 묶음 이름 바꾸기: 권한 > 이름 검증 > 교체 (이미 보낸 오늘 일과의 묶음 이름은 그대로)
  @Transactional
  public RoutineGroupResponse rename(Caller caller, String groupId, String name) {
    RoutineGroup group = groupFor(caller, groupId);
    group.setName(validateName(name));
    return RoutineGroupResponse.of(group, idsOf(routineGroupMembership.membersOf(groupId)));
  }

  /**
   * 묶음 구성 바꾸기 (넣기·빼기·순서 한 번에): 권한 > 구성원 검증 > 목록에서 빠진 일과 내보내기 > 받은 차례대로 넣기
   */
  @Transactional
  public RoutineGroupResponse replaceRoutines(Caller caller, String groupId, List<String> routineIds) {
    RoutineGroup group = groupFor(caller, groupId);
    List<Routine> members = loadMembers(group.getProfile().getId(), routineIds);
    Set<String> keptRoutineIds = new HashSet<>(idsOf(members));
    for (Routine current : routineGroupMembership.membersOf(groupId)) {
      if (!keptRoutineIds.contains(current.getId())) {
        current.setGroupId(null);
        current.setGroupOrder(null);
      }
    }
    routineGroupMembership.assign(groupId, members);
    return RoutineGroupResponse.of(group, idsOf(members));
  }

  /// 묶음 풀기: 권한 > 구성원 묶음 정보 비우기 > 묶음 삭제 (일과는 그대로)
  @Transactional
  public void delete(Caller caller, String groupId) {
    groupFor(caller, groupId);
    routineGroupMembership.dissolve(groupId);
  }

  /**
   * 묶음 복사하기: 권한 > 구성원(2개 이상) > "이름 복사" 새 묶음(맨 뒤) > 구성원마다 일과관리 전용 복사본(제목 그대로) > 같은 차례로 넣기
   */
  @Transactional
  public RoutineGroupResponse copy(Caller caller, String groupId) {
    RoutineGroup group = groupFor(caller, groupId);
    List<Routine> members = requireMembers(groupId);
    String copyName = RoutineLibraryService.toCopyName(group.getName(), members.get(0).getLanguage(),
      GROUP_NAME_MAX_LENGTH);
    RoutineGroup copiedGroup = routineGroupRepository.save(newGroup(group.getProfile(), caller.memberId(), copyName,
      nextLibraryOrder(group.getProfile().getId())));
    List<Routine> copies = members.stream()
      .map(member -> routineLibraryService.newLibraryCopyOf(member, caller.memberId(), false))
      .toList();
    routineGroupMembership.assign(copiedGroup.getId(), copies);
    List<Routine> savedCopies = copies.stream().map(routineLibraryService::saveCopy).toList();
    return RoutineGroupResponse.of(copiedGroup, idsOf(savedCopies));
  }

  /**
   * 묶음째 보내기: 권한 > 구성원(2개 이상) > 차례대로 오늘 일과 만들기(묶음 ID·이름·차례 스냅샷) > 오늘 이미 보낸 일과는 건너뜀
   * 하나도 못 보냈으면 409 ROUTINE_ALREADY_SENT_TODAY
   */
  @Transactional
  public List<RoutineResponse> send(Caller caller, String groupId) {
    RoutineGroup group = groupFor(caller, groupId);
    List<Routine> members = requireMembers(groupId);
    List<RoutineResponse> sentRoutines = new ArrayList<>();
    Routine firstSentRoutine = null;
    for (int order = 0; order < members.size(); order++) {
      Routine member = members.get(order);
      if (routineLibraryService.isAlreadySentToday(member)) {
        continue;
      }
      Routine todayCopy = routineLibraryService.newTodayCopyOf(member, caller.memberId());
      todayCopy.setSentGroupId(group.getId());
      todayCopy.setSentGroupName(group.getName());
      // 묶음 안 자리 그대로 (건너뛴 일과 자리는 비움)
      todayCopy.setSentGroupOrder(order);
      Routine savedTodayCopy = routineLibraryService.saveCopy(todayCopy);
      if (firstSentRoutine == null) {
        firstSentRoutine = savedTodayCopy;
      }
      sentRoutines.add(RoutineResponse.from(savedTodayCopy));
    }
    if (sentRoutines.isEmpty()) {
      log.info("[routine group] send rejected 409 : all routines already sent today, groupId={}", groupId);
      throw new CustomException(ErrorCode.ROUTINE_ALREADY_SENT_TODAY);
    }
    // 묶음 1회 보내기는 알림 1건 (첫 번째로 만든 일과 기준)
    routineLibraryService.publishRoutineSent(caller, firstSentRoutine);
    return sentRoutines;
  }

  /// 묶음 꺼내기 + 권한 (이룸이 휴대폰 403, 없는 묶음·남의 이룸이 묶음 404)
  private RoutineGroup groupFor(Caller caller, String groupId) {
    if (caller.isElumi()) {
      throw new CustomException(ErrorCode.DEVICE_LINK_FORBIDDEN_FOR_ELUMI);
    }
    RoutineGroup group = routineGroupRepository.findById(groupId)
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_GROUP_NOT_FOUND));
    if (!profileAccessGuard.isGuardianOf(caller.memberId(), group.getProfile().getId())) {
      throw new CustomException(ErrorCode.ROUTINE_GROUP_NOT_FOUND);
    }
    return group;
  }

  /// 지금 구성원 (2개 미만으로 줄어든 묶음은 목록에도 없으니 없는 묶음으로 봄)
  private List<Routine> requireMembers(String groupId) {
    List<Routine> members = routineGroupMembership.membersOf(groupId);
    if (members.size() < RoutineGroupMembership.GROUP_MIN_ROUTINE_COUNT) {
      throw new CustomException(ErrorCode.ROUTINE_GROUP_NOT_FOUND);
    }
    return members;
  }

  /// 묶음 이름 정리 (앞뒤 공백 제거, 1~12자 아니면 INVALID_INPUT_VALUE)
  private String validateName(String name) {
    String trimmedName = name == null ? "" : name.trim();
    if (trimmedName.isEmpty() || trimmedName.length() > GROUP_NAME_MAX_LENGTH) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    return trimmedName;
  }

  /**
   * 구성원 검증 > 받은 차례대로 일과: 빈 ID·중복(INVALID_INPUT_VALUE) > 2개 미만(TOO_SMALL) > 원본 조건(INVALID_MEMBER)
   * 원본 조건 4개: 이 이룸이 일과, 보내기로 만든 일과 아님, 일과관리에서 지우지 않음, 보낸 상태(CONFIRMED·COMPLETED)
   */
  private List<Routine> loadMembers(String profileId, List<String> routineIds) {
    List<String> requestedIds = routineIds == null ? List.of() : routineIds;
    if (requestedIds.stream().anyMatch(id -> id == null || id.isBlank())
      || new HashSet<>(requestedIds).size() != requestedIds.size()) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    if (requestedIds.size() < RoutineGroupMembership.GROUP_MIN_ROUTINE_COUNT) {
      throw new CustomException(ErrorCode.ROUTINE_GROUP_TOO_SMALL);
    }
    Map<String, Routine> routineById = routineRepository.findAllById(requestedIds).stream()
      .collect(Collectors.toMap(Routine::getId, Function.identity()));
    List<Routine> members = requestedIds.stream().map(routineById::get).toList();
    if (members.stream().anyMatch(routine -> !isGroupableOriginal(routine, profileId))) {
      log.info("[routine group] rejected 400 : invalid member, profileId={}", profileId);
      throw new CustomException(ErrorCode.ROUTINE_GROUP_INVALID_MEMBER);
    }
    return members;
  }

  private boolean isGroupableOriginal(Routine routine, String profileId) {
    return routine != null
      && Objects.equals(routine.getProfile().getId(), profileId)
      && routine.getSourceRoutineId() == null
      && !routine.isLibraryHidden()
      && (routine.getStatus() == RoutineStatus.CONFIRMED || routine.getStatus() == RoutineStatus.COMPLETED);
  }

  /// 새 칸 자리: 묶음 칸·낱개 칸을 통틀어 맨 뒤 (#844)
  private int nextLibraryOrder(String profileId) {
    return Math.max(routineGroupRepository.maxDisplayOrder(profileId), routineRepository.maxLibraryOrder(profileId)) + 1;
  }

  /// 새 묶음 (저장 전, 칸 자리 지정)
  private RoutineGroup newGroup(Profile profile, String createdBy, String name, int displayOrder) {
    RoutineGroup group = new RoutineGroup();
    group.setProfile(profile);
    group.setCreatedBy(createdBy);
    group.setName(name);
    group.setDisplayOrder(displayOrder);
    return group;
  }

  private List<String> idsOf(List<Routine> routines) {
    return routines.stream().map(Routine::getId).toList();
  }
}
