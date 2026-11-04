package com.chuseok22.elumserver.routine.application.service;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;

import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 이룸이 정리(나가기·탈퇴) 때 AI 메모 삭제 (#1082). 깨지면 탈퇴한 보호자가 고친 카드에서 배운 메모가 남는다
 */
@ExtendWith(MockitoExtension.class)
class RoutineMemoryForgetTest {

  @Mock private com.chuseok22.elumserver.member.application.service.ProfileAccessGuard profileAccessGuard;
  @Mock private com.chuseok22.elumserver.license.application.service.EntitlementService entitlementService;
  @Mock private RoutineMemoryRepository routineMemoryRepository;
  @Mock private RoutineMemoryRows routineMemoryRows;
  @Mock private RoutineRepository routineRepository;
  @InjectMocks private RoutineMemoryService service;

  @Test
  @DisplayName("메모 행을 지우고 남은 일과의 AI 처음 카드 기록도 비운다")
  void forgetProfile_deletesMemoryAndDrafts() {
    service.forgetProfile("profile-1");

    verify(routineMemoryRepository).deleteByProfileId("profile-1");
    verify(routineRepository).clearAiDraftCardsOfProfile(eq("profile-1"), any());
  }
}
