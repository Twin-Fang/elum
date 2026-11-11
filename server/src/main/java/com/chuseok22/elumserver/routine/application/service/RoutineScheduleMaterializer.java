package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.notification.application.service.ElumiPushDispatcher;
import com.chuseok22.elumserver.notification.core.ElumiNotificationState;
import com.chuseok22.elumserver.notification.core.event.RoutineTimeArrivedEvent;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineSchedule;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineScheduleRepository;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 반복 예약 한 건 실행 (예약 하나 = 트랜잭션 하나): 오늘 일과 만들기, 정한 시각 알림
 * 같은 날 두 번 막기는 예약 행의 날짜 차지(조건부 update)로 함. 요일·요금제 판정은 부르는 쪽(RoutineScheduleRunner)
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RoutineScheduleMaterializer {

  private final RoutineScheduleRepository routineScheduleRepository;
  private final RoutineRepository routineRepository;
  private final RoutineStepSpeechQueue routineStepSpeechQueue;
  private final ApplicationEventPublisher eventPublisher;
  private final ElumiPushDispatcher elumiPushDispatcher;

  /** 그날 일과 만들기: 원본 확인 > 날짜 차지 > (그날 안 보냈으면) 카드 복사, 그 시각으로 > 그날 일과 */
  @Transactional
  public Optional<Routine> materialize(String scheduleId, LocalDate date) {
    return routineScheduleRepository.findById(scheduleId).flatMap(schedule -> materialize(schedule, date));
  }

  /**
   * 정한 시각: 그날 일과 만들기 > 알림 조건 확인(켜짐, 아직 안 끝냄, 받을 기기 있음) > 알림 날짜 차지 > 커밋 뒤 이룸이 기기 푸시
   * 받을 기기가 없으면 날짜를 차지하지 않음 (되짚는 폭 안에 기기를 연결하면 그날 알림이 감). 푸시 실패는 리스너가 기록만 함
   */
  @Transactional
  public RoutineScheduleRunResult materializeAndNotify(String scheduleId, LocalDate date) {
    Optional<RoutineSchedule> foundSchedule = routineScheduleRepository.findById(scheduleId);
    if (foundSchedule.isEmpty()) {
      return RoutineScheduleRunResult.NO_ROUTINE;
    }
    RoutineSchedule schedule = foundSchedule.get();
    Optional<Routine> todayRoutine = materialize(schedule, date);
    if (todayRoutine.isEmpty()) {
      return RoutineScheduleRunResult.NO_ROUTINE;
    }
    if (!schedule.isNotifyEnabled()) {
      return RoutineScheduleRunResult.NOTIFY_OFF;
    }
    Routine routine = todayRoutine.get();
    if (isFinished(routine)) {
      return RoutineScheduleRunResult.ALREADY_FINISHED;
    }
    // 연결 없음·알림 토큰 없음 > 보낼 곳이 없음 (NOTIFIED 로 세지 않음)
    if (elumiPushDispatcher.notificationStateOf(schedule.getProfileId()) != ElumiNotificationState.ON) {
      return RoutineScheduleRunResult.NO_DEVICE;
    }
    if (routineScheduleRepository.claimNotification(schedule.getId(), date) == 0) {
      return RoutineScheduleRunResult.ALREADY_NOTIFIED;
    }
    eventPublisher.publishEvent(new RoutineTimeArrivedEvent(routine.getId(), schedule.getProfileId(), schedule.getId()));
    return RoutineScheduleRunResult.NOTIFIED;
  }

  private Optional<Routine> materialize(RoutineSchedule schedule, LocalDate date) {
    Optional<Routine> original = routineRepository.findById(schedule.getRoutineId())
      .filter(routine -> isLiveOriginalOf(routine, schedule));
    if (original.isEmpty()) {
      // 원본이 지워졌거나 일과관리에서 빠짐 > 예약도 정리 (다시 정할 원본이 없음)
      routineScheduleRepository.delete(schedule);
      log.info("[routine schedule] removed : original gone, scheduleId={}", schedule.getId());
      return Optional.empty();
    }
    Routine sourceRoutine = original.get();
    boolean isClaimed = routineScheduleRepository.claimMaterialization(schedule.getId(), date) == 1;
    if (isClaimed && !RoutineRules.isSentOn(routineRepository, sourceRoutine, date)) {
      return Optional.of(saveDayCopy(sourceRoutine, schedule, date));
    }
    return findDayRoutine(sourceRoutine, date);
  }

  // 원본 카드 > 그날 일과 (그 시각, 원본 ID 기록). 알림 이벤트(일과 도착)는 내지 않음: 정한 시각 알림이 따로 감
  private Routine saveDayCopy(Routine original, RoutineSchedule schedule, LocalDate date) {
    Routine copy = RoutineRules.copyCardsOf(original, schedule.getOwnerMemberId());
    copy.setSourceRoutineId(original.getId());
    copy.setLibraryOnly(false);
    copy.setScheduledAt(date.atTime(schedule.getTimeOfDay()));
    Routine saved = RoutineRules.saveWithSpeech(routineRepository, routineStepSpeechQueue, copy);
    log.info("[routine schedule] materialized : scheduleId={} date={}", schedule.getId(), date);
    return saved;
  }

  // 그날 이미 있는 일과: 원본 자체가 그날 홈 일과면 원본, 아니면 이 원본으로 보낸 그날 일과
  private Optional<Routine> findDayRoutine(Routine original, LocalDate date) {
    if (RoutineRules.isOriginalOnHomeOn(original, date)) {
      return Optional.of(original);
    }
    return routineRepository.findFirstBySourceRoutineIdAndScheduledAtBetweenOrderByCreatedAtDesc(original.getId(),
      date.atStartOfDay(), date.atTime(LocalTime.MAX));
  }

  // 살아 있는 원본 조건 3개: 보낼 수 있는 원본, 일과관리에서 지우지 않음, 예약과 같은 이룸이
  private boolean isLiveOriginalOf(Routine routine, RoutineSchedule schedule) {
    return RoutineRules.isSendableOriginal(routine)
      && !routine.isLibraryHidden()
      && routine.getProfile() != null
      && schedule.getProfileId().equals(routine.getProfile().getId());
  }

  private boolean isFinished(Routine routine) {
    return routine.getStatus() == RoutineStatus.COMPLETED || routine.getCompletedAt() != null;
  }
}
