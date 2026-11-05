package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.notification.application.service.ElumiPushDispatcher;
import com.chuseok22.elumserver.notification.core.ElumiNotificationState;
import com.chuseok22.elumserver.notification.core.event.RoutineTimeArrivedEvent;
import com.chuseok22.elumserver.routine.core.RoutineScheduleWeekdays;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineSchedule;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineScheduleRepository;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;

/// 반복 일과 한 건 실행 (#782, #1080): 같은 날 두 벌·두 번 알림 없음, 끝낸 일과는 알림 생략
@ExtendWith(MockitoExtension.class)
class RoutineScheduleMaterializerTest {

  // 2026-11-09 은 월요일
  private static final LocalDate MONDAY = LocalDate.of(2026, 11, 9);
  private static final LocalTime EIGHT = LocalTime.of(8, 0);

  @Mock
  private RoutineScheduleRepository routineScheduleRepository;
  @Mock
  private RoutineRepository routineRepository;
  @Mock
  private RoutineStepSpeechQueue routineStepSpeechQueue;
  @Mock
  private ApplicationEventPublisher eventPublisher;
  @Mock
  private ElumiPushDispatcher elumiPushDispatcher;

  @InjectMocks
  private RoutineScheduleMaterializer materializer;

  @Test
  @DisplayName("처음 차지하면 원본 카드로 그 시각 오늘 일과를 만든다 — 이룸이가 그날 일과를 받지 못하면 반복이 소용없다")
  void materialize_firstClaim_createsDayCopyAtScheduledTime() {
    givenSchedule(schedule(true));
    givenOriginal(original());
    when(routineScheduleRepository.claimMaterialization("schedule-1", MONDAY)).thenReturn(1);
    when(routineRepository.existsBySourceRoutineIdAndScheduledAtBetween(eq("routine-1"), any(), any()))
      .thenReturn(false);
    ArgumentCaptor<Routine> saved = ArgumentCaptor.forClass(Routine.class);
    when(routineRepository.save(saved.capture())).thenAnswer(invocation -> invocation.getArgument(0));

    Optional<Routine> dayRoutine = materializer.materialize("schedule-1", MONDAY);

    assertThat(dayRoutine).isPresent();
    assertThat(saved.getValue().getSourceRoutineId()).isEqualTo("routine-1");
    assertThat(saved.getValue().getScheduledAt()).isEqualTo(MONDAY.atTime(EIGHT));
    assertThat(saved.getValue().getCreatedBy()).isEqualTo("owner-1");
    assertThat(saved.getValue().isLibraryOnly()).isFalse();
    assertThat(saved.getValue().getStatus()).isEqualTo(RoutineStatus.CONFIRMED);
  }

  @Test
  @DisplayName("이미 차지한 날은 새로 만들지 않고 그날 일과를 돌려준다 — 조회가 겹쳐도 같은 일과가 두 번 뜨지 않는다")
  void materialize_alreadyClaimed_doesNotCreateSecondCopy() {
    givenSchedule(schedule(true));
    givenOriginal(original());
    when(routineScheduleRepository.claimMaterialization("schedule-1", MONDAY)).thenReturn(0);
    Routine existing = dayCopy(RoutineStatus.CONFIRMED);
    when(routineRepository.findFirstBySourceRoutineIdAndScheduledAtBetweenOrderByCreatedAtDesc(eq("routine-1"), any(),
      any())).thenReturn(Optional.of(existing));

    Optional<Routine> dayRoutine = materializer.materialize("schedule-1", MONDAY);

    assertThat(dayRoutine).containsSame(existing);
    verify(routineRepository, never()).save(any());
  }

  @Test
  @DisplayName("보호자가 그날 이미 손으로 보냈으면 만들지 않는다 — 오늘 보내기와 반복이 겹쳐 두 줄이 되지 않는다")
  void materialize_manuallySentToday_doesNotCreateCopy() {
    givenSchedule(schedule(true));
    givenOriginal(original());
    when(routineScheduleRepository.claimMaterialization("schedule-1", MONDAY)).thenReturn(1);
    when(routineRepository.existsBySourceRoutineIdAndScheduledAtBetween(eq("routine-1"), any(), any()))
      .thenReturn(true);
    when(routineRepository.findFirstBySourceRoutineIdAndScheduledAtBetweenOrderByCreatedAtDesc(eq("routine-1"), any(),
      any())).thenReturn(Optional.of(dayCopy(RoutineStatus.CONFIRMED)));

    materializer.materialize("schedule-1", MONDAY);

    verify(routineRepository, never()).save(any());
  }

  @Test
  @DisplayName("일과관리에서 지운 원본이면 예약을 정리하고 아무것도 만들지 않는다")
  void materialize_hiddenOriginal_removesSchedule() {
    RoutineSchedule schedule = schedule(true);
    givenSchedule(schedule);
    Routine hidden = original();
    hidden.setLibraryHidden(true);
    givenOriginal(hidden);

    assertThat(materializer.materialize("schedule-1", MONDAY)).isEmpty();
    verify(routineScheduleRepository).delete(schedule);
    verify(routineRepository, never()).save(any());
  }

  @Test
  @DisplayName("정한 시각에 아직 안 끝낸 일과면 이룸이 기기 알림 이벤트를 낸다 (오늘 일과 ID)")
  void notify_unfinished_publishesEventWithDayRoutineId() {
    givenSchedule(schedule(true));
    givenOriginal(original());
    givenAlreadyMaterialized(dayCopy(RoutineStatus.CONFIRMED));
    givenElumiNotification(ElumiNotificationState.ON);
    when(routineScheduleRepository.claimNotification("schedule-1", MONDAY)).thenReturn(1);

    RoutineScheduleRunResult runResult = materializer.materializeAndNotify("schedule-1", MONDAY);

    assertThat(runResult).isEqualTo(RoutineScheduleRunResult.NOTIFIED);
    ArgumentCaptor<RoutineTimeArrivedEvent> event = ArgumentCaptor.forClass(RoutineTimeArrivedEvent.class);
    verify(eventPublisher).publishEvent(event.capture());
    assertThat(event.getValue().routineId()).isEqualTo("day-copy-1");
    assertThat(event.getValue().profileId()).isEqualTo("profile-1");
    assertThat(event.getValue().scheduleId()).isEqualTo("schedule-1");
  }

  @Test
  @DisplayName("받을 이룸이 기기가 없으면 NOTIFIED 로 세지 않고 알림 날짜도 차지하지 않는다 — 로그가 '보냈다'고 거짓말하지 않는다")
  void notify_noElumiDevice_countsNoDeviceWithoutClaim() {
    givenSchedule(schedule(true));
    givenOriginal(original());
    givenAlreadyMaterialized(dayCopy(RoutineStatus.CONFIRMED));
    givenElumiNotification(ElumiNotificationState.NO_DEVICE);

    assertThat(materializer.materializeAndNotify("schedule-1", MONDAY))
      .isEqualTo(RoutineScheduleRunResult.NO_DEVICE);
    verify(routineScheduleRepository, never()).claimNotification(any(), any());
    verify(eventPublisher, never()).publishEvent(any());
  }

  @Test
  @DisplayName("이미 끝낸 일과면 알림을 보내지 않는다 — 다 한 일을 다시 하라고 재촉하지 않는다")
  void notify_finished_skipsPush() {
    givenSchedule(schedule(true));
    givenOriginal(original());
    givenAlreadyMaterialized(dayCopy(RoutineStatus.COMPLETED));

    assertThat(materializer.materializeAndNotify("schedule-1", MONDAY))
      .isEqualTo(RoutineScheduleRunResult.ALREADY_FINISHED);
    verify(eventPublisher, never()).publishEvent(any());
    verify(routineScheduleRepository, never()).claimNotification(any(), any());
  }

  @Test
  @DisplayName("오늘 이미 알렸으면(서버 둘이 같은 분에 돌아도) 두 번 울리지 않는다")
  void notify_alreadyNotified_skipsPush() {
    givenSchedule(schedule(true));
    givenOriginal(original());
    givenAlreadyMaterialized(dayCopy(RoutineStatus.CONFIRMED));
    givenElumiNotification(ElumiNotificationState.ON);
    when(routineScheduleRepository.claimNotification("schedule-1", MONDAY)).thenReturn(0);

    assertThat(materializer.materializeAndNotify("schedule-1", MONDAY))
      .isEqualTo(RoutineScheduleRunResult.ALREADY_NOTIFIED);
    verify(eventPublisher, never()).publishEvent(any());
  }

  @Test
  @DisplayName("알림을 끈 예약은 오늘 일과만 만들고 알리지 않는다")
  void notify_notifyOff_onlyMaterializes() {
    givenSchedule(schedule(false));
    givenOriginal(original());
    givenAlreadyMaterialized(dayCopy(RoutineStatus.CONFIRMED));

    assertThat(materializer.materializeAndNotify("schedule-1", MONDAY))
      .isEqualTo(RoutineScheduleRunResult.NOTIFY_OFF);
    verify(eventPublisher, never()).publishEvent(any());
  }

  private void givenSchedule(RoutineSchedule schedule) {
    when(routineScheduleRepository.findById("schedule-1")).thenReturn(Optional.of(schedule));
  }

  private void givenElumiNotification(ElumiNotificationState state) {
    when(elumiPushDispatcher.notificationStateOf("profile-1")).thenReturn(state);
  }

  private void givenOriginal(Routine original) {
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(original));
  }

  private void givenAlreadyMaterialized(Routine dayCopy) {
    when(routineScheduleRepository.claimMaterialization("schedule-1", MONDAY)).thenReturn(0);
    when(routineRepository.findFirstBySourceRoutineIdAndScheduledAtBetweenOrderByCreatedAtDesc(eq("routine-1"), any(),
      any())).thenReturn(Optional.of(dayCopy));
  }

  private RoutineSchedule schedule(boolean isNotifyEnabled) {
    RoutineSchedule schedule = new RoutineSchedule();
    schedule.setId("schedule-1");
    schedule.setRoutineId("routine-1");
    schedule.setProfileId("profile-1");
    schedule.setOwnerMemberId("owner-1");
    schedule.setWeekdaysMask(RoutineScheduleWeekdays.toMask(List.of(DayOfWeek.MONDAY)));
    schedule.setTimeOfDay(EIGHT);
    schedule.setNotifyEnabled(isNotifyEnabled);
    return schedule;
  }

  private Profile profile() {
    Profile profile = new Profile();
    profile.setId("profile-1");
    return profile;
  }

  // 일과관리 원본: 지난주에 만든 보낸 상태 (오늘 홈 일과 아님)
  private Routine original() {
    Routine routine = new Routine();
    routine.setId("routine-1");
    routine.setProfile(profile());
    routine.setCreatedBy("member-1");
    routine.setTitle("아침 준비");
    routine.setRawInputText("원문");
    routine.setSanitizedInputText("원문");
    routine.setStatus(RoutineStatus.CONFIRMED);
    routine.setScheduledAt(MONDAY.minusDays(7).atTime(9, 0));
    routine.setLanguage(AppLocale.KO);
    RoutineStep step = new RoutineStep();
    step.setRoutine(routine);
    step.setStepOrder(1);
    step.setTitle("양치하기");
    step.setCompleted(false);
    routine.setSteps(new ArrayList<>(List.of(step)));
    return routine;
  }

  private Routine dayCopy(RoutineStatus status) {
    Routine copy = new Routine();
    copy.setId("day-copy-1");
    copy.setProfile(profile());
    copy.setSourceRoutineId("routine-1");
    copy.setStatus(status);
    copy.setScheduledAt(MONDAY.atTime(EIGHT));
    return copy;
  }
}
