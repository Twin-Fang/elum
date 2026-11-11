package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.notification.application.service.ElumiPushDispatcher;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineScheduleSaveRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineScheduleResponse;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineSchedule;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineScheduleRepository;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/// 요일·시각 저장 (#782): Free 는 403, 요일 0개는 400, 시각을 바꾸면 오늘 다시 울릴 수 있음
@ExtendWith(MockitoExtension.class)
class RoutineScheduleServiceTest {

  private static final Caller GUARDIAN = Caller.guardian("member-1");

  @Mock
  private RoutineScheduleRepository routineScheduleRepository;
  @Mock
  private RoutineRepository routineRepository;
  @Mock
  private ProfileAccessGuard profileAccessGuard;
  @Mock
  private EntitlementService entitlementService;
  @Mock
  private RoutineScheduleRunner routineScheduleRunner;
  @Mock
  private ElumiPushDispatcher elumiPushDispatcher;

  @InjectMocks
  private RoutineScheduleService routineScheduleService;

  @Test
  @DisplayName("Free 보호자가 저장하면 ROUTINE_SCHEDULE_NOT_ALLOWED — 새 기능은 Pro 다")
  void save_free_rejected() {
    givenOriginal();
    doThrow(new CustomException(Entitlement.ROUTINE_SCHEDULE.rejectionCode())).when(entitlementService).requireAllowed("member-1", Entitlement.ROUTINE_SCHEDULE);

    assertThatThrownBy(() -> routineScheduleService.save(GUARDIAN, "routine-1",
      new RoutineScheduleSaveRequest(List.of("MONDAY"), "08:00", true)))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(ErrorCode.ROUTINE_SCHEDULE_NOT_ALLOWED);
    verify(routineScheduleRepository, never()).save(any());
  }

  @Test
  @DisplayName("요일을 하나도 고르지 않으면 ROUTINE_SCHEDULE_INVALID")
  void save_emptyWeekdays_rejected() {
    givenOriginal();

    assertThatThrownBy(() -> routineScheduleService.save(GUARDIAN, "routine-1",
      new RoutineScheduleSaveRequest(List.of(), "08:00", true)))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(ErrorCode.ROUTINE_SCHEDULE_INVALID);
  }

  @Test
  @DisplayName("시각을 바꾸면 오늘 알림 기록을 지우고 요일은 월요일부터 돌려준다 — 바꾼 시각에 오늘 다시 울려야 한다")
  void save_timeChanged_resetsTodayNotification() {
    givenOriginal();
    RoutineSchedule existing = new RoutineSchedule();
    existing.setRoutineId("routine-1");
    existing.setTimeOfDay(LocalTime.of(8, 0));
    existing.setLastNotifiedDate(LocalDate.of(2026, 11, 9));
    when(routineScheduleRepository.findByRoutineId("routine-1")).thenReturn(Optional.of(existing));
    when(routineScheduleRepository.save(any())).thenAnswer(invocation -> invocation.getArgument(0));

    RoutineScheduleResponse response = routineScheduleService.save(GUARDIAN, "routine-1",
      new RoutineScheduleSaveRequest(List.of("sunday", "MONDAY"), "15:30", null));

    assertThat(existing.getLastNotifiedDate()).isNull();
    assertThat(existing.getOwnerMemberId()).isEqualTo("member-1");
    assertThat(response.weekdays()).containsExactly("MONDAY", "SUNDAY");
    assertThat(response.time()).isEqualTo("15:30");
    assertThat(response.notifyEnabled()).isTrue();
  }

  private void givenOriginal() {
    Profile profile = new Profile();
    profile.setId("profile-1");
    Routine routine = new Routine();
    routine.setId("routine-1");
    routine.setProfile(profile);
    routine.setCreatedBy("member-1");
    routine.setStatus(RoutineStatus.CONFIRMED);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));
  }
}
