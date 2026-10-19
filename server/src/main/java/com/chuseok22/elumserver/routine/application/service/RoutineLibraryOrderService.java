package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineLibraryOrderRequest.Cell;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineLibraryOrderRequest.CellType;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineGroup;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineGroupRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.util.Comparator;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 일과관리 칸 순서 저장 (#844): 낱개 원본과 묶음을 한 번호 공간(0부터)에 세움
 * 받은 차례 > 0..n-1, 빠뜨린 칸은 기존 순서대로 뒤에 이어 붙임 (아무것도 지우지 않음)
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RoutineLibraryOrderService {

  private final RoutineRepository routineRepository;
  private final RoutineGroupRepository routineGroupRepository;
  private final ProfileAccessGuard profileAccessGuard;

  /**
   * 칸 순서 저장: 권한(보호자) > 요청 형태 검증(빈 ID·중복) > 이 이룸이 칸인지 검증 > 받은 차례, 빠진 칸(묶음 먼저) 순으로 번호 매김
   * 칸 조건: 낱개 = 묶음 밖·원본·지우지 않음·보낸 상태, 묶음 = 이 이룸이 묶음
   */
  @Transactional
  public void reorder(Caller caller, List<Cell> cells) {
    String profileId = profileAccessGuard.profileFor(caller, ProfileAction.MANAGE).getId();
    List<Cell> requestedCells = cells == null ? List.of() : cells;
    validateShape(requestedCells);

    // 이 이룸이가 가진 칸 (낱개는 현재 칸 순서 > 최신순)
    Map<String, Routine> looseRoutineById = new LinkedHashMap<>();
    routineRepository.findLibraryOriginals(profileId, List.of(RoutineStatus.CONFIRMED, RoutineStatus.COMPLETED))
      .stream()
      .filter(routine -> routine.getGroupId() == null)
      .sorted(Comparator.comparing(Routine::getLibraryOrder, Comparator.nullsLast(Comparator.naturalOrder())))
      .forEach(routine -> looseRoutineById.put(routine.getId(), routine));
    Map<String, RoutineGroup> groupById = new LinkedHashMap<>();
    routineGroupRepository.findAllByProfileIdOrderByDisplayOrderAscCreatedAtAsc(profileId)
      .forEach(group -> groupById.put(group.getId(), group));

    // 받은 차례
    int nextOrder = 0;
    for (Cell cell : requestedCells) {
      if (cell.type() == CellType.GROUP) {
        RoutineGroup group = groupById.remove(cell.id());
        if (group == null) {
          throw rejectUnknownCell(profileId, cell);
        }
        group.setDisplayOrder(nextOrder++);
      } else {
        Routine routine = looseRoutineById.remove(cell.id());
        if (routine == null) {
          throw rejectUnknownCell(profileId, cell);
        }
        routine.setLibraryOrder(nextOrder++);
      }
    }
    // 빠진 칸: 묶음 > 낱개 (목록 기본 순서와 같음)
    for (RoutineGroup group : groupById.values()) {
      group.setDisplayOrder(nextOrder++);
    }
    for (Routine routine : looseRoutineById.values()) {
      routine.setLibraryOrder(nextOrder++);
    }
  }

  /// 형태 검증: 종류·ID 비어 있음, 같은 칸 두 번 (INVALID_INPUT_VALUE)
  private void validateShape(List<Cell> cells) {
    Set<String> seenKeys = new HashSet<>();
    for (Cell cell : cells) {
      if (cell == null || cell.type() == null || cell.id() == null || cell.id().isBlank()
        || !seenKeys.add(cell.type() + ":" + cell.id())) {
        throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
      }
    }
  }

  /// 없는 칸·남의 이룸이 칸·묶음 안 일과·지운 일과: 모두 같은 400 (ID 값은 로그에 남기지 않음)
  private CustomException rejectUnknownCell(String profileId, Cell cell) {
    log.info("[routine library order] rejected 400 : unknown cell, profileId={}, type={}", profileId, cell.type());
    return new CustomException(ErrorCode.ROUTINE_GROUP_INVALID_MEMBER);
  }
}
