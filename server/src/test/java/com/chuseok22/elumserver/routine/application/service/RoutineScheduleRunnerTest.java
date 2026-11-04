package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.notification.core.NotificationTime;
import com.chuseok22.elumserver.routine.core.RoutineScheduleWeekdays;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineSchedule;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineScheduleRepository;
import java.time.Clock;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/// 반복 일과 실행 판정 (#782, #1080): 요일(한국 시각)·자정 경계·Pro 끝남 멈춤
@ExtendWith(MockitoExtension.class)
class RoutineScheduleRunnerTest {

  // 2026-11-08 일요일, 2026-11-09 월요일
  private static final LocalDate SUNDAY = LocalDate.of(2026, 11, 8);
  private static final LocalDate MONDAY = LocalDate.of(2026, 11, 9);

  @Mock
  private RoutineScheduleRepository routineScheduleRepository;
  @Mock
  private RoutineScheduleMaterializer materializer;
  @Mock
  private EntitlementService entitlementService;
  @Mock
  private ProfileAccessGuard profileAccessGuard;

  @Test
  @DisplayName("월요일 0시 작업은 어제(일요일) 밤 시각으로 되짚지 않는다 — 일요일 23:58 예약이 월요일에 울리면 엉뚱한 날 일과다")
  void notifyDue_atMidnight_doesNotLookBackIntoYesterday() {
    RoutineScheduleRunner runner = runnerAt(MONDAY.atTime(0, 0));
    when(routineScheduleRepository.findAllByTimeOfDayBetween(LocalTime.MIN, LocalTime.MIDNIGHT)).thenReturn(List.of());

    runner.notifyDue();

    verify(routineScheduleRepository).findAllByTimeOfDayBetween(LocalTime.MIN, LocalTime.MIDNIGHT);
  }

  @Test
  @DisplayName("일요일만 고른 예약은 월요일에 울리지 않는다 (요일은 한국 시각 날짜로 본다)")
  void notifyDue_sundayOnlySchedule_skippedOnMonday() {
    RoutineScheduleRunner runner = runnerAt(MONDAY.atTime(8, 0));
    RoutineSchedule sundayOnly = schedule(DayOfWeek.SUNDAY, LocalTime.of(8, 0));
    when(routineScheduleRepository.findAllByTimeOfDayBetween(LocalTime.of(7, 55), LocalTime.of(8, 0)))
      .thenReturn(List.of(sundayOnly));

    Map<RoutineScheduleRunResult, Integer> counts = runner.notifyDue();

    assertThat(counts).isEmpty();
    verify(materializer, never()).materializeAndNotify(any(), any());
  }

  @Test
  @DisplayName("일요일 예약은 일요일에 실행한다")
  void notifyDue_sundaySchedule_runsOnSunday() {
    RoutineScheduleRunner runner = runnerAt(SUNDAY.atTime(19, 30));
    RoutineSchedule sunday = schedule(DayOfWeek.SUNDAY, LocalTime.of(19, 30));
    when(routineScheduleRepository.findAllByTimeOfDayBetween(LocalTime.of(19, 25), LocalTime.of(19, 30)))
      .thenReturn(List.of(sunday));
    givenOwnerActive(true);
    when(materializer.materializeAndNotify("schedule-1", SUNDAY)).thenReturn(RoutineScheduleRunResult.NOTIFIED);

    assertThat(runner.notifyDue()).containsEntry(RoutineScheduleRunResult.NOTIFIED, 1);
  }

  @Test
  @DisplayName("Pro 가 끝난 보호자의 예약은 멈춘다 — 일과도 만들지 않고 알림도 보내지 않는다 (예약은 지우지 않음)")
  void notifyDue_proEnded_pausesWithoutPush() {
    RoutineScheduleRunner runner = runnerAt(MONDAY.atTime(8, 0));
    RoutineSchedule monday = schedule(DayOfWeek.MONDAY, LocalTime.of(8, 0));
    when(routineScheduleRepository.findAllByTimeOfDayBetween(LocalTime.of(7, 55), LocalTime.of(8, 0)))
      .thenReturn(List.of(monday));
    givenOwnerActive(false);

    assertThat(runner.notifyDue()).containsEntry(RoutineScheduleRunResult.PAUSED, 1);
    verify(materializer, never()).materializeAndNotify(any(), any());
    verify(routineScheduleRepository, never()).delete(any());
  }

  @Test
  @DisplayName("오늘 일과 조회 전 만들기는 오늘 요일이고 아직 안 만든 예약만 부른다")
  void materializeToday_onlyTodayAndNotYetMaterialized() {
    RoutineScheduleRunner runner = runnerAt(MONDAY.atTime(6, 0));
    RoutineSchedule mondayPending = schedule(DayOfWeek.MONDAY, LocalTime.of(8, 0));
    RoutineSchedule mondayDone = schedule(DayOfWeek.MONDAY, LocalTime.of(9, 0));
    mondayDone.setId("schedule-2");
    mondayDone.setLastMaterializedDate(MONDAY);
    RoutineSchedule tuesday = schedule(DayOfWeek.TUESDAY, LocalTime.of(8, 0));
    tuesday.setId("schedule-3");
    when(routineScheduleRepository.findAllByProfileId("profile-1"))
      .thenReturn(List.of(mondayPending, mondayDone, tuesday));
    givenOwnerActive(true);

    runner.materializeTodayFor("profile-1");

    verify(materializer).materialize("schedule-1", MONDAY);
    verify(materializer, never()).materialize("schedule-2", MONDAY);
    verify(materializer, never()).materialize("schedule-3", MONDAY);
  }

  private void givenOwnerActive(boolean isProActive) {
    when(profileAccessGuard.isGuardianOf("owner-1", "profile-1")).thenReturn(true);
    when(entitlementService.isAllowed("owner-1", Entitlement.ROUTINE_SCHEDULE)).thenReturn(isProActive);
  }

  private RoutineScheduleRunner runnerAt(LocalDateTime koreanNow) {
    Clock clock = Clock.fixed(koreanNow.atZone(NotificationTime.ZONE_ID).toInstant(), NotificationTime.ZONE_ID);
    return new RoutineScheduleRunner(routineScheduleRepository, materializer, entitlementService, profileAccessGuard,
      clock);
  }

  private RoutineSchedule schedule(DayOfWeek weekday, LocalTime time) {
    RoutineSchedule schedule = new RoutineSchedule();
    schedule.setId("schedule-1");
    schedule.setRoutineId("routine-1");
    schedule.setProfileId("profile-1");
    schedule.setOwnerMemberId("owner-1");
    schedule.setWeekdaysMask(RoutineScheduleWeekdays.toMask(List.of(weekday)));
    schedule.setTimeOfDay(time);
    return schedule;
  }
}
