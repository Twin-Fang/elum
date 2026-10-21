package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineLibraryOrderRequest.Cell;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineLibraryOrderRequest.CellType;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineGroup;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineGroupRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/// 일과관리 칸 순서(#844): 낱개 + 묶음 한 번호 공간 · 빠진 칸은 뒤로 · 남의 칸·묶음 안 일과·중복은 거절
@ExtendWith(MockitoExtension.class)
class RoutineLibraryOrderServiceTest {

  private static final Caller GUARDIAN = Caller.guardian("member-1");

  @Mock
  private RoutineRepository routineRepository;
  @Mock
  private RoutineGroupRepository routineGroupRepository;
  @Mock
  private ProfileAccessGuard profileAccessGuard;

  private RoutineLibraryOrderService service;
  private Routine looseA;
  private Routine looseB;
  private Routine looseC;
  private Routine inGroup;
  private RoutineGroup folder;

  @BeforeEach
  void setUp() {
    service = new RoutineLibraryOrderService(routineRepository, routineGroupRepository, profileAccessGuard);
    Profile profile = new Profile();
    profile.setId("profile-1");
    lenient().when(profileAccessGuard.profileFor(eq(GUARDIAN), any(ProfileAction.class))).thenReturn(profile);
    looseA = routine("routine-a", null);
    looseB = routine("routine-b", null);
    looseC = routine("routine-c", null);
    inGroup = routine("routine-in-group", "group-1");
    folder = new RoutineGroup();
    folder.setId("group-1");
    folder.setDisplayOrder(0);
    when(routineRepository.findLibraryOriginals(eq("profile-1"), any())).thenReturn(List.of(looseA, looseB, looseC, inGroup));
    when(routineGroupRepository.findAllByProfileIdOrderByDisplayOrderAscCreatedAtAsc("profile-1")).thenReturn(List.of(folder));
  }

  @Test
  @DisplayName("받은 차례가 낱개·묶음 한 번호 공간의 0부터 자리가 되고, 빠진 칸은 뒤에 기존 순서로 붙는다")
  void reorder_numbersCellsInOneSpace_andAppendsOmittedCells() {
    service.reorder(GUARDIAN, List.of(cell(CellType.ROUTINE, "routine-c"), cell(CellType.GROUP, "group-1")));

    assertThat(looseC.getLibraryOrder()).isZero();
    assertThat(folder.getDisplayOrder()).isEqualTo(1);
    assertThat(looseA.getLibraryOrder()).isEqualTo(2);
    assertThat(looseB.getLibraryOrder()).isEqualTo(3);
    // 묶음 안 일과는 낱개 칸이 아니라 건드리지 않음
    assertThat(inGroup.getLibraryOrder()).isNull();
  }

  @Test
  @DisplayName("없는 ID · 묶음 안 일과 · 종류가 다른 ID는 INVALID_MEMBER, 중복은 INVALID_INPUT_VALUE — 어느 쪽도 번호를 바꾸지 않는다")
  void reorder_rejectsForeignCells_andDuplicates_withoutChangingOrder() {
    assertThatThrownBy(() -> service.reorder(GUARDIAN, List.of(cell(CellType.ROUTINE, "foreign"))))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_GROUP_INVALID_MEMBER);
    assertThatThrownBy(() -> service.reorder(GUARDIAN, List.of(cell(CellType.ROUTINE, "routine-in-group"))))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_GROUP_INVALID_MEMBER);
    assertThatThrownBy(() -> service.reorder(GUARDIAN, List.of(cell(CellType.GROUP, "routine-a"))))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_GROUP_INVALID_MEMBER);
    assertThatThrownBy(() -> service.reorder(GUARDIAN,
      List.of(cell(CellType.ROUTINE, "routine-a"), cell(CellType.ROUTINE, "routine-a"))))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.INVALID_INPUT_VALUE);
    assertThat(looseA.getLibraryOrder()).isNull();
  }

  @Test
  @DisplayName("맨 앞 자리 만들기: 번호 있는 낱개·묶음은 한 칸씩 밀리고, 번호 없는 칸·묶음 안 일과는 그대로다")
  void makeRoomAtFront_shiftsNumberedCellsByOne() {
    looseA.setLibraryOrder(0);
    looseC.setLibraryOrder(3);
    folder.setDisplayOrder(1);

    service.makeRoomAtFront("profile-1");

    assertThat(looseA.getLibraryOrder()).isEqualTo(1);
    assertThat(looseC.getLibraryOrder()).isEqualTo(4);
    assertThat(folder.getDisplayOrder()).isEqualTo(2);
    assertThat(looseB.getLibraryOrder()).isNull();
    assertThat(inGroup.getLibraryOrder()).isNull();
  }

  private static Cell cell(CellType type, String id) {
    return new Cell(type, id);
  }

  private static Routine routine(String id, String groupId) {
    Routine routine = new Routine();
    routine.setId(id);
    routine.setGroupId(groupId);
    return routine;
  }
}
