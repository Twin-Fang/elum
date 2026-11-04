package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryResponse;
import com.chuseok22.elumserver.routine.core.RoutineMemoryLine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemory;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 보호자의 AI 메모 관리 (#1082). 깨지면 Free 가 메모를 쓰거나, 보호자가 진단을 적어 저장되거나, 탈퇴·나가기 뒤 메모가 남는다
 */
@ExtendWith(MockitoExtension.class)
class RoutineMemoryServiceTest {

  private static final Caller GUARDIAN = Caller.guardian("member-1");
  private static final String PROFILE_ID = "profile-1";

  @Mock private ProfileAccessGuard profileAccessGuard;
  @Mock private EntitlementService entitlementService;
  @Mock private RoutineMemoryRepository routineMemoryRepository;
  @Mock private RoutineMemoryRows routineMemoryRows;
  @Mock private RoutineRepository routineRepository;
  @InjectMocks private RoutineMemoryService service;

  @BeforeEach
  void profile() {
    Profile profile = new Profile();
    profile.setId(PROFILE_ID);
    when(profileAccessGuard.profileFor(GUARDIAN, ProfileAction.MANAGE)).thenReturn(profile);
  }

  @Test
  @DisplayName("Free: 보기는 빈 응답(available=false), 쓰기는 403 ROUTINE_MEMORY_PRO_REQUIRED")
  void free_cannotWrite() {
    when(entitlementService.isAllowed("member-1", Entitlement.ROUTINE_MEMORY)).thenReturn(false);

    assertThat(service.get(GUARDIAN).available()).isFalse();
    assertThatThrownBy(() -> service.replaceLines(GUARDIAN, List.of("짧게 나눠요")))
      .isInstanceOf(CustomException.class)
      .extracting(e -> ((CustomException) e).getErrorCode()).isEqualTo(ErrorCode.ROUTINE_MEMORY_PRO_REQUIRED);
  }

  @Test
  @DisplayName("보호자가 적은 줄에 진단·장애 표현이 있으면 400 ROUTINE_MEMORY_LINE_NOT_ALLOWED 로 저장하지 않는다")
  void guardianForbiddenLine_rejected() {
    when(entitlementService.isAllowed("member-1", Entitlement.ROUTINE_MEMORY)).thenReturn(true);

    assertThatThrownBy(() -> service.replaceLines(GUARDIAN, List.of("자폐가 있어요")))
      .isInstanceOf(CustomException.class)
      .extracting(e -> ((CustomException) e).getErrorCode()).isEqualTo(ErrorCode.ROUTINE_MEMORY_LINE_NOT_ALLOWED);
  }

  @Test
  @DisplayName("줄 바꾸기: 같은 AI 줄은 AI, 새 줄은 GUARDIAN, 빠진 AI 줄은 지운 줄로 기억")
  void replaceLines_tracksSourceAndDismissed() {
    when(entitlementService.isAllowed("member-1", Entitlement.ROUTINE_MEMORY)).thenReturn(true);
    RoutineMemory memory = new RoutineMemory();
    memory.setLines(RoutineMemoryJson.writeLines(List.of(
      new RoutineMemoryLine("AI 줄 하나", RoutineMemoryLine.Source.AI),
      new RoutineMemoryLine("AI 줄 둘", RoutineMemoryLine.Source.AI))));
    when(routineMemoryRows.findOrCreate(PROFILE_ID)).thenReturn(memory);

    RoutineMemoryResponse response = service.replaceLines(GUARDIAN, List.of("AI 줄 하나", "내가 쓴 줄"));

    assertThat(response.lines()).extracting(RoutineMemoryResponse.LineResponse::source)
      .containsExactly(RoutineMemoryLine.Source.AI, RoutineMemoryLine.Source.GUARDIAN);
    assertThat(RoutineMemoryJson.readTexts(memory.getDismissedLines())).containsExactly("AI 줄 둘");
  }

  @Test
  @DisplayName("모두 지우기: 줄을 비우고 이 이룸이 일과의 AI 처음 카드 기록도 비운다 (다시 배우지 않게)")
  void clear_alsoForgetsDrafts() {
    when(entitlementService.isAllowed("member-1", Entitlement.ROUTINE_MEMORY)).thenReturn(true);
    RoutineMemory memory = new RoutineMemory();
    memory.setLines(RoutineMemoryJson.writeLines(List.of(new RoutineMemoryLine("줄", RoutineMemoryLine.Source.AI))));
    when(routineMemoryRows.findOrCreate(PROFILE_ID)).thenReturn(memory);

    assertThat(service.clear(GUARDIAN).lines()).isEmpty();
    verify(routineRepository).clearAiDraftCardsOfProfile(eq(PROFILE_ID), any());
  }
}
