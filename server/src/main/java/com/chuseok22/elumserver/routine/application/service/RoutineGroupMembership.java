package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineGroupRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * 묶음 구성원 관리: 넣기(옮기기), 빼기, 풀기 (#806)
 * 규칙 2개: 일과는 한 묶음에만, 묶음은 일과 2개 이상(밑돌면 풀기). 묶음을 풀어도 일과는 지우지 않음
 * 묶음 서비스·일과관리 지우기·일과 삭제가 함께 씀 (서로 부르면 순환이라 따로 둠)
 */
@Component
@RequiredArgsConstructor
public class RoutineGroupMembership {

  /// 묶음 최소 일과 수
  static final int GROUP_MIN_ROUTINE_COUNT = 2;

  private final RoutineRepository routineRepository;
  private final RoutineGroupRepository routineGroupRepository;

  /**
   * 묶음에 일과 넣기: 받은 차례대로 groupId·groupOrder(0부터) > 다른 묶음에서 옮겨 온 일과면 그 묶음이 2개 미만일 때 풀기
   * 이 묶음에서 빠질 일과는 호출부가 먼저 뺌
   */
  void assign(String groupId, List<Routine> orderedRoutines) {
    Set<String> previousGroupIds = new LinkedHashSet<>();
    for (int order = 0; order < orderedRoutines.size(); order++) {
      Routine routine = orderedRoutines.get(order);
      if (routine.getGroupId() != null && !routine.getGroupId().equals(groupId)) {
        previousGroupIds.add(routine.getGroupId());
      }
      routine.setGroupId(groupId);
      routine.setGroupOrder(order);
    }
    previousGroupIds.forEach(this::dissolveIfTooSmall);
  }

  /// 일과 하나를 묶음에서 빼기 > 남은 일과가 2개 미만이면 묶음 풀기. 묶음 밖 일과면 아무것도 안 함
  void leaveGroup(Routine routine) {
    String groupId = routine.getGroupId();
    if (groupId == null) {
      return;
    }
    clearGroup(routine);
    dissolveIfTooSmall(groupId);
  }

  /// 묶음 풀기: 구성원 groupId·groupOrder 비우기 > 묶음 행 삭제 (일과는 그대로)
  void dissolve(String groupId) {
    membersOf(groupId).forEach(this::clearGroup);
    routineGroupRepository.deleteById(groupId);
  }

  /// 지금 이 묶음을 가리키는 일과, 차례대로 (같은 트랜잭션에서 이미 뺀 일과 제외)
  List<Routine> membersOf(String groupId) {
    return routineRepository.findAllByGroupIdOrderByGroupOrderAsc(groupId).stream()
      .filter(routine -> groupId.equals(routine.getGroupId()))
      .toList();
  }

  /// 남은 일과 2개 미만 > 풀기, 아니면 차례를 0부터 다시 매김 (빠진 자리 메우기)
  private void dissolveIfTooSmall(String groupId) {
    List<Routine> remaining = membersOf(groupId);
    if (remaining.size() < GROUP_MIN_ROUTINE_COUNT) {
      remaining.forEach(this::clearGroup);
      routineGroupRepository.deleteById(groupId);
      return;
    }
    for (int order = 0; order < remaining.size(); order++) {
      remaining.get(order).setGroupOrder(order);
    }
  }

  private void clearGroup(Routine routine) {
    routine.setGroupId(null);
    routine.setGroupOrder(null);
  }
}
