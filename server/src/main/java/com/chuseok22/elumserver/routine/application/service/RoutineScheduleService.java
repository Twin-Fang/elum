package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.RoutineAction;
import com.chuseok22.elumserver.notification.application.service.ElumiPushDispatcher;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineScheduleSaveRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineScheduleListResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineScheduleResponse;
import com.chuseok22.elumserver.routine.core.RoutineScheduleWeekdays;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineSchedule;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineScheduleRepository;
import java.time.DayOfWeek;
import java.time.LocalTime;
import java.time.format.DateTimeParseException;
import java.util.Comparator;
import java.util.EnumSet;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 보호자의 반복 요일·시각: 주간 계획 조회, 저장(Pro), 끄기(누구나) (#782, #1080)
 * 저장한 보호자가 예약 주인 (실행 여부는 그 사람 요금제). 이룸이 기기는 쓰지도 보지도 않음
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RoutineScheduleService {

  private final RoutineScheduleRepository routineScheduleRepository;
  private final RoutineRepository routineRepository;
  private final ProfileAccessGuard profileAccessGuard;
  private final EntitlementService entitlementService;
  private final RoutineScheduleRunner routineScheduleRunner;
  private final ElumiPushDispatcher elumiPushDispatcher;

  /** 주간 계획: 이룸이 확인(이룸이 기기 거절) > 살아 있는 원본의 예약만, 시각 순 > 멈춤 표시 > 기기 알림 상태 */
  public RoutineScheduleListResponse list(Caller caller) {
    String profileId = profileAccessGuard.profileFor(caller, ProfileAction.MANAGE).getId();
    List<RoutineSchedule> schedules = routineScheduleRepository.findAllByProfileId(profileId);
    Set<String> liveOriginalIds = liveOriginalIdsOf(schedules, profileId);
    Map<String, Boolean> isActiveByOwner = new HashMap<>();
    List<RoutineScheduleResponse> responses = schedules.stream()
      .filter(schedule -> liveOriginalIds.contains(schedule.getRoutineId()))
      .sorted(Comparator.comparing(RoutineSchedule::getTimeOfDay))
      .map(schedule -> RoutineScheduleResponse.of(schedule, !isActiveByOwner.computeIfAbsent(
        schedule.getOwnerMemberId(), ignored -> routineScheduleRunner.isOwnerActive(schedule))))
      .toList();
    boolean canSchedule = entitlementService.isAllowed(caller.memberId(), Entitlement.ROUTINE_SCHEDULE);
    return new RoutineScheduleListResponse(responses, canSchedule,
      elumiPushDispatcher.notificationStateOf(profileId).name());
  }

  /**
   * 저장: 권한(보내기와 같음) > 원본 확인 > 요금제 > 요일·시각 검증 > 덮어쓰기 (주인 = 저장한 보호자)
   * 시각을 바꾸면 오늘 알림 기록을 지움 (바꾼 시각에 오늘 다시 울릴 수 있게). 오늘 일과 기록은 그대로 (두 벌 막기)
   */
  @Transactional
  public RoutineScheduleResponse save(Caller caller, String routineId, RoutineScheduleSaveRequest request) {
    Routine original = originalFor(caller, routineId);
    entitlementService.requireAllowed(caller.memberId(), Entitlement.ROUTINE_SCHEDULE);
    int weekdaysMask = toWeekdaysMask(request);
    LocalTime timeOfDay = toTimeOfDay(request);

    RoutineSchedule schedule = routineScheduleRepository.findByRoutineId(routineId).orElseGet(RoutineSchedule::new);
    if (!timeOfDay.equals(schedule.getTimeOfDay())) {
      schedule.setLastNotifiedDate(null);
    }
    schedule.setRoutineId(routineId);
    schedule.setProfileId(original.getProfile().getId());
    schedule.setOwnerMemberId(caller.memberId());
    schedule.setWeekdaysMask(weekdaysMask);
    schedule.setTimeOfDay(timeOfDay);
    schedule.setNotifyEnabled(request.notifyEnabled() == null || request.notifyEnabled());
    return RoutineScheduleResponse.of(routineScheduleRepository.save(schedule), false);
  }

  /** 끄기: 권한(보내기와 같음) > 예약 지움. 요금제와 무관 (Pro 가 끝나도 끌 수 있음). 이미 오늘 만든 일과는 그대로 */
  @Transactional
  public void delete(Caller caller, String routineId) {
    originalFor(caller, routineId);
    routineScheduleRepository.deleteByRoutineId(routineId);
  }

  // 원본 확인: 이룸이 기기 거절 > 보내기 권한 > 보낼 수 있는 원본이고 일과관리에서 지우지 않음
  private Routine originalFor(Caller caller, String routineId) {
    if (caller.isElumi()) {
      throw new CustomException(ErrorCode.DEVICE_LINK_FORBIDDEN_FOR_ELUMI);
    }
    Routine routine = RoutineRules.routineFor(routineRepository, profileAccessGuard, caller, routineId,
      RoutineAction.COPY);
    if (!RoutineRules.isSendableOriginal(routine) || routine.isLibraryHidden()) {
      log.info("[routine schedule] rejected 409 : not a library original, routineId={}", routineId);
      throw new CustomException(ErrorCode.ROUTINE_INVALID_STATUS);
    }
    return routine;
  }

  // 요일 검증: 1개 이상, MONDAY ~ SUNDAY 이름만 (대소문자 무시)
  private int toWeekdaysMask(RoutineScheduleSaveRequest request) {
    if (request == null || request.weekdays() == null || request.weekdays().isEmpty()) {
      throw invalid("weekdays empty");
    }
    Set<DayOfWeek> weekdays = EnumSet.noneOf(DayOfWeek.class);
    for (String weekday : request.weekdays()) {
      try {
        weekdays.add(DayOfWeek.valueOf(weekday == null ? "" : weekday.trim().toUpperCase()));
      } catch (IllegalArgumentException exception) {
        throw invalid("weekday unknown");
      }
    }
    return RoutineScheduleWeekdays.toMask(weekdays);
  }

  // 시각 검증: HH:mm (초는 버림)
  private LocalTime toTimeOfDay(RoutineScheduleSaveRequest request) {
    if (request.time() == null) {
      throw invalid("time empty");
    }
    try {
      return LocalTime.parse(request.time().trim(), RoutineScheduleResponse.TIME_FORMAT);
    } catch (DateTimeParseException exception) {
      throw invalid("time format");
    }
  }

  private CustomException invalid(String reason) {
    log.info("[routine schedule] save rejected 400 : {}", reason);
    return new CustomException(ErrorCode.ROUTINE_SCHEDULE_INVALID);
  }

  // 예약이 가리키는 일과 중 살아 있는 원본 ID (지운 원본은 목록에서 빠지고 1분 작업이 정리)
  private Set<String> liveOriginalIdsOf(List<RoutineSchedule> schedules, String profileId) {
    if (schedules.isEmpty()) {
      return Set.of();
    }
    List<String> routineIds = schedules.stream().map(RoutineSchedule::getRoutineId).toList();
    return routineRepository.findAllByIdInAndProfileIdIn(routineIds, List.of(profileId)).stream()
      .filter(routine -> RoutineRules.isSendableOriginal(routine) && !routine.isLibraryHidden())
      .map(Routine::getId)
      .collect(Collectors.toSet());
  }
}
