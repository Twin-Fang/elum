package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.notification.core.NotificationTime;
import com.chuseok22.elumserver.routine.core.RoutineScheduleWeekdays;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineSchedule;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineScheduleRepository;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.temporal.ChronoUnit;
import java.util.EnumMap;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/**
 * 반복 예약 실행 2곳: 오늘 일과 조회 전(그날 일과 미리 만들기), 1분마다(정한 시각 알림)
 * 판정 3개: 오늘 요일인가, 저장한 보호자가 아직 이 이룸이의 보호자인가, 그 보호자 요금제가 ROUTINE_SCHEDULE 인가 (아니면 멈춤, 지우지 않음)
 * 예약 하나 실패는 로그만 (다음 예약은 계속). 날짜는 한국 시각
 */
@Slf4j
@Service
public class RoutineScheduleRunner {

  /// 1분 작업이 놓친 시각을 되짚는 폭 (배포·재시작으로 몇 분 비어도 그날 알림을 살림)
  static final int CATCH_UP_MINUTES = 5;

  private final RoutineScheduleRepository routineScheduleRepository;
  private final RoutineScheduleMaterializer routineScheduleMaterializer;
  private final EntitlementService entitlementService;
  private final ProfileAccessGuard profileAccessGuard;
  private final Clock clock;

  @Autowired
  public RoutineScheduleRunner(RoutineScheduleRepository routineScheduleRepository,
    RoutineScheduleMaterializer routineScheduleMaterializer, EntitlementService entitlementService,
    ProfileAccessGuard profileAccessGuard) {
    this(routineScheduleRepository, routineScheduleMaterializer, entitlementService, profileAccessGuard,
      Clock.system(NotificationTime.ZONE_ID));
  }

  RoutineScheduleRunner(RoutineScheduleRepository routineScheduleRepository,
    RoutineScheduleMaterializer routineScheduleMaterializer, EntitlementService entitlementService,
    ProfileAccessGuard profileAccessGuard, Clock clock) {
    this.routineScheduleRepository = routineScheduleRepository;
    this.routineScheduleMaterializer = routineScheduleMaterializer;
    this.entitlementService = entitlementService;
    this.profileAccessGuard = profileAccessGuard;
    this.clock = clock;
  }

  /** 오늘 일과 조회 전 (보호자·이룸이 기기 공통): 요청이 가리키는 이룸이 > 오늘 요일 예약 만들기. 어떤 실패도 던지지 않음 */
  public void materializeTodayFor(Caller caller) {
    try {
      materializeTodayFor(profileAccessGuard.profileFor(caller, ProfileAction.VIEW).getId());
    } catch (RuntimeException exception) {
      // 이룸이 확인 실패(403·404)는 이어지는 조회가 같은 코드로 답함
      log.debug("[routine schedule] materialize skipped : {}", exception.getClass().getSimpleName());
    }
  }

  /** 이 이룸이의 오늘 요일 예약 > 아직 안 만든 것만 오늘 일과로 (시각이 지나기 전부터 목록에 뜸) */
  public void materializeTodayFor(String profileId) {
    LocalDate today = LocalDate.now(clock);
    Map<String, Boolean> isActiveByOwner = new HashMap<>();
    for (RoutineSchedule schedule : routineScheduleRepository.findAllByProfileId(profileId)) {
      if (!RoutineScheduleWeekdays.isOn(schedule.getWeekdaysMask(), today.getDayOfWeek())
        || today.equals(schedule.getLastMaterializedDate())
        || !isActive(schedule, isActiveByOwner)) {
        continue;
      }
      try {
        routineScheduleMaterializer.materialize(schedule.getId(), today);
      } catch (RuntimeException exception) {
        // 만들기 실패가 오늘 일과 조회를 막지 않음
        log.warn("[routine schedule] materialize failed : scheduleId={} {}", schedule.getId(),
          exception.getClass().getSimpleName());
      }
    }
  }

  /** 1분마다: 지금까지 되짚는 폭 안의 시각 예약 > 오늘 요일만 > 오늘 일과 만들기 + 알림. 결과별 건수 */
  public Map<RoutineScheduleRunResult, Integer> notifyDue() {
    LocalDateTime now = LocalDateTime.now(clock).truncatedTo(ChronoUnit.MINUTES);
    LocalDate today = now.toLocalDate();
    Map<RoutineScheduleRunResult, Integer> countByResult = new EnumMap<>(RoutineScheduleRunResult.class);
    Map<String, Boolean> isActiveByOwner = new HashMap<>();
    for (RoutineSchedule schedule : dueSchedulesAt(now.toLocalTime())) {
      if (!RoutineScheduleWeekdays.isOn(schedule.getWeekdaysMask(), today.getDayOfWeek())
        || today.equals(schedule.getLastNotifiedDate())) {
        continue;
      }
      RoutineScheduleRunResult runResult = isActive(schedule, isActiveByOwner)
        ? runOne(schedule, today)
        : RoutineScheduleRunResult.PAUSED;
      countByResult.merge(runResult, 1, Integer::sum);
    }
    if (!countByResult.isEmpty()) {
      log.info("[routine schedule] tick {} : {}", now.toLocalTime(), countByResult);
    }
    return countByResult;
  }

  // 되짚는 폭: 지금 - 5분 ~ 지금 (자정을 넘겨 어제로 가지 않음: 어제 시각은 어제 일)
  private List<RoutineSchedule> dueSchedulesAt(LocalTime now) {
    LocalTime from = now.minusMinutes(CATCH_UP_MINUTES);
    if (from.isAfter(now)) {
      from = LocalTime.MIN;
    }
    return routineScheduleRepository.findAllByTimeOfDayBetween(from, now);
  }

  private RoutineScheduleRunResult runOne(RoutineSchedule schedule, LocalDate today) {
    try {
      return routineScheduleMaterializer.materializeAndNotify(schedule.getId(), today);
    } catch (RuntimeException exception) {
      log.warn("[routine schedule] notify failed : scheduleId={} {}", schedule.getId(),
        exception.getClass().getSimpleName());
      return RoutineScheduleRunResult.NO_ROUTINE;
    }
  }

  // 실행해도 되는가: 저장한 보호자가 아직 이 이룸이 보호자 + 요금제 권한 (한 번 실행에서 보호자마다 한 번만 물음)
  private boolean isActive(RoutineSchedule schedule, Map<String, Boolean> isActiveByOwner) {
    String key = schedule.getOwnerMemberId() + "|" + schedule.getProfileId();
    return isActiveByOwner.computeIfAbsent(key, ignored -> isOwnerActive(schedule));
  }

  /** 저장한 보호자 기준으로 이 예약이 돌 수 있는가 (주간 계획의 멈춤 표시와 같은 판정) */
  boolean isOwnerActive(RoutineSchedule schedule) {
    return profileAccessGuard.isGuardianOf(schedule.getOwnerMemberId(), schedule.getProfileId())
      && entitlementService.isAllowed(schedule.getOwnerMemberId(), Entitlement.ROUTINE_SCHEDULE);
  }
}
