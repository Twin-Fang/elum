package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportInsightsResponse;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportResponse;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportWeeksResponse;
import com.chuseok22.elumserver.routine.core.ReportWeek;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 주간 리포트 읽기 전용 조회: 한 주 집계, 마친 일과가 있는 주 목록, 가장 이른 주, 지난주 대상 이룸이
 * 트랜잭션을 여기서 닫음 (AI 호출·푸시가 있는 호출부가 DB 연결을 쥐고 기다리지 않게)
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class WeeklyReportReader {

  /// 집계 대상 상태: 이룸이에게 보낸 일과 (임시저장 제외) — 홈 오늘·지난 일과와 같은 기준
  private static final List<RoutineStatus> SENT_STATUSES = List.of(RoutineStatus.CONFIRMED, RoutineStatus.COMPLETED);
  /// 주 목록 최대 개수
  static final int MAX_LISTED_WEEKS = 26;
  /// 주 목록을 가르려고 읽는 마친 일과 시각 상한 (최근 26주를 채우고도 남는 양)
  private static final int MAX_SCANNED_COMPLETED_ROUTINES = 3000;

  private final RoutineRepository routineRepository;

  /// 이룸이 한 명의 한 주 집계 (그 주 보낸 일과, 일과관리 복사본 제외)
  public WeeklyReportResponse aggregate(String profileId, ReportWeek week, LocalDate today) {
    List<Routine> routines = sentRoutinesOf(profileId, week);
    WeeklyReportResponse report = WeeklyReportAggregator.aggregate(week, routines, today);
    return report.withInsights(insightsOf(profileId, week, report, routines, today));
  }

  /// 집계 + 이룸이 호칭·일과 언어 (월요일 알림용). 그 주 보낸 일과가 없으면 empty
  public Optional<ReportWithNickname> aggregateWithNickname(String profileId, ReportWeek week, LocalDate today) {
    List<Routine> routines = sentRoutinesOf(profileId, week);
    if (routines.isEmpty()) {
      return Optional.empty();
    }
    Routine latest = routines.get(routines.size() - 1);
    AppLocale language = latest.getLanguage() == null ? AppLocale.KO : latest.getLanguage();
    return Optional.of(new ReportWithNickname(
      WeeklyReportAggregator.aggregate(week, routines, today), latest.getProfile().getNickname(), language));
  }

  /// 마친 일과가 있는 주 (최신순, 최대 26개)
  public List<WeeklyReportWeeksResponse.Week> listRecordedWeeks(String profileId) {
    List<LocalDateTime> completedAts = routineRepository.findScheduledAtsByProfileIdAndStatus(
      profileId, RoutineStatus.COMPLETED, PageRequest.of(0, MAX_SCANNED_COMPLETED_ROUTINES));
    Map<LocalDate, Integer> completedCountByWeekStart = new LinkedHashMap<>();
    for (LocalDateTime completedAt : completedAts) {
      LocalDate weekStart = ReportWeek.containing(completedAt.toLocalDate()).start();
      if (!completedCountByWeekStart.containsKey(weekStart) && completedCountByWeekStart.size() >= MAX_LISTED_WEEKS) {
        break;
      }
      completedCountByWeekStart.merge(weekStart, 1, Integer::sum);
    }
    return completedCountByWeekStart.entrySet().stream()
      .map(entry -> new WeeklyReportWeeksResponse.Week(entry.getKey(), entry.getValue()))
      .toList();
  }

  /// 마친 일과가 있는 가장 이른 주의 월요일 (Free 첫 주 미리 보기 대상, 없으면 empty)
  public Optional<LocalDate> findEarliestRecordedWeekStart(String profileId) {
    LocalDateTime earliest = routineRepository.findEarliestScheduledAtByProfileIdAndStatus(
      profileId, RoutineStatus.COMPLETED);
    return Optional.ofNullable(earliest).map(at -> ReportWeek.containing(at.toLocalDate()).start());
  }

  /// 그 주에 마친 일과가 있는 이룸이 id
  public List<String> findProfileIdsWithCompletedRoutines(ReportWeek week) {
    return routineRepository.findProfileIdsWithStatusBetween(RoutineStatus.COMPLETED, week.startAt(), week.lastMoment());
  }

  /// 인사이트: 기록 없는 주면 null. 지난주 일과·이전 완료 열쇠를 각 1회 조회
  private WeeklyReportInsightsResponse insightsOf(String profileId, ReportWeek week, WeeklyReportResponse report,
    List<Routine> routines, LocalDate today) {
    if (routines.isEmpty()) {
      return null;
    }
    List<Routine> previousRoutines = sentRoutinesOf(profileId, ReportWeek.containing(week.start().minusWeeks(1)));
    Set<String> priorCompletedKeys = new HashSet<>(
      routineRepository.findCompletedRoutineKeysBefore(profileId, RoutineStatus.COMPLETED, week.startAt()));
    return WeeklyReportInsightCalculator.calculate(report.longestCompletedDayStreak(), routines, previousRoutines,
      priorCompletedKeys, today, routineRepository::existsById);
  }

  private List<Routine> sentRoutinesOf(String profileId, ReportWeek week) {
    return routineRepository
      .findAllWithStepsByProfileIdAndStatusInAndScheduledAtBetween(
        profileId, SENT_STATUSES, week.startAt(), week.lastMoment())
      .stream()
      .filter(routine -> !routine.isLibraryOnly())
      .toList();
  }

  /// 집계 + 이룸이 호칭 + 그 주 마지막 일과의 언어
  public record ReportWithNickname(WeeklyReportResponse report, String nickname, AppLocale language) {

  }
}
