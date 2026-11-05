package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportResponse;
import com.chuseok22.elumserver.routine.core.ReportWeek;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.time.LocalDate;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 주간 리포트 조회 (#1074): 이룸이 확인 > 요금제 확인 > 주 정하기 > 그 주 보낸 일과 집계
 * 보호자 전용 (이룸이 기기는 MANAGE 에서 막힘), 읽기만
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class WeeklyReportService {

  /// 집계 대상 상태: 이룸이에게 보낸 일과 (임시저장 제외) — 홈 오늘·지난 일과와 같은 기준
  private static final List<RoutineStatus> SENT_STATUSES = List.of(RoutineStatus.CONFIRMED, RoutineStatus.COMPLETED);

  private final RoutineRepository routineRepository;
  private final ProfileAccessGuard profileAccessGuard;
  private final EntitlementService entitlementService;

  /// requestedWeekStart: 그 주 아무 날 (null 이면 이번 주). 오늘이 든 주보다 뒤면 400
  public WeeklyReportResponse getWeeklyReport(Caller caller, LocalDate requestedWeekStart) {
    String profileId = profileAccessGuard.profileFor(caller, ProfileAction.MANAGE).getId();
    requireWeeklyReportAllowed(caller);

    LocalDate today = LocalDate.now();
    ReportWeek week = resolveWeek(requestedWeekStart, today);

    // 그 주 보낸 일과 (일과관리 복사본은 보낸 적이 없어 제외)
    List<Routine> sentRoutines = routineRepository
      .findAllByProfileIdAndStatusInAndScheduledAtBetweenOrderByScheduledAtAsc(
        profileId, SENT_STATUSES, week.startAt(), week.lastMoment())
      .stream()
      .filter(routine -> !routine.isLibraryOnly())
      .toList();
    return WeeklyReportAggregator.aggregate(week, sentRoutines, today);
  }

  /// 요금제 확인: WEEKLY_REPORT 꺼짐 > 403 WEEKLY_REPORT_NOT_ALLOWED (이룸이 기기의 계정은 연결해 준 보호자)
  private void requireWeeklyReportAllowed(Caller caller) {
    entitlementService.requireAllowed(caller.memberId(), Entitlement.WEEKLY_REPORT);
  }

  /// 요청 날짜 > 그 날이 든 주. 없으면 이번 주, 이번 주보다 뒤면 INVALID_INPUT_VALUE
  private static ReportWeek resolveWeek(LocalDate requestedWeekStart, LocalDate today) {
    ReportWeek currentWeek = ReportWeek.containing(today);
    if (requestedWeekStart == null) {
      return currentWeek;
    }
    ReportWeek requestedWeek = ReportWeek.containing(requestedWeekStart);
    if (requestedWeek.isAfter(currentWeek)) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    return requestedWeek;
  }
}
