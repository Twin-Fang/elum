package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportResponse;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportResponse.Day;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportResponse.RemainingStep;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportResponse.RoutineSummary;
import com.chuseok22.elumserver.routine.core.ReportWeek;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import java.time.LocalDate;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

/**
 * 한 주 일과 목록 > 주간 리포트 (DB 없음, 순수 계산)
 * 집계 4개: 완료율·별·보상, 하루 칸·연속, 일과별 묶음, 남은 카드
 */
final class WeeklyReportAggregator {

  /// 남은 카드 최대 개수 — 한 장에 다 들어가고 보호자가 한눈에 볼 만큼
  static final int REMAINING_STEP_LIMIT = 3;

  private WeeklyReportAggregator() {
  }

  /// routines: 이 주에 보낸 일과(CONFIRMED·COMPLETED, 복사본 제외). today: 진행 중인 오늘을 가르는 기준
  static WeeklyReportResponse aggregate(ReportWeek week, List<Routine> routines, LocalDate today) {
    // 완료율·별·보상
    int sentCount = routines.size();
    int completedCount = (int) routines.stream().filter(WeeklyReportAggregator::isCompleted).count();
    int starsEarned = routines.stream().mapToInt(routine -> RoutineRules.countCompleted(routine.getSteps())).sum();
    int rewardReachedCount = (int) routines.stream()
      .filter(routine -> isCompleted(routine) && hasReward(routine))
      .count();

    // 하루 칸·연속
    List<Day> days = toDays(week, routines);

    return new WeeklyReportResponse(
      week.start(),
      week.lastDay(),
      week.equals(ReportWeek.containing(today)),
      sentCount,
      completedCount,
      toPercent(completedCount, sentCount),
      starsEarned,
      rewardReachedCount,
      longestCompletedDayStreak(days),
      days,
      toRoutineSummaries(routines),
      toRemainingSteps(routines, today),
      null
    );
  }

  /// 마친 일과 / 보낸 일과 > 0~100 반올림. 보낸 일과 0이면 0
  static int toPercent(int completedCount, int sentCount) {
    if (sentCount == 0) {
      return 0;
    }
    return (int) Math.round(completedCount * 100.0 / sentCount);
  }

  private static List<Day> toDays(ReportWeek week, List<Routine> routines) {
    return week.days().stream()
      .map(date -> {
        List<Routine> ofDay = routines.stream()
          .filter(routine -> routine.getScheduledAt().toLocalDate().equals(date))
          .toList();
        int completedOfDay = (int) ofDay.stream().filter(WeeklyReportAggregator::isCompleted).count();
        return new Day(date, ofDay.size(), completedOfDay);
      })
      .toList();
  }

  /// 일과를 하나 이상 마친 날이 이어진 가장 긴 길이
  static int longestCompletedDayStreak(List<Day> days) {
    int longest = 0;
    int current = 0;
    for (Day day : days) {
      current = day.completedCount() > 0 ? current + 1 : 0;
      longest = Math.max(longest, current);
    }
    return longest;
  }

  /// 같은 원본에서 보낸 일과를 하나로 묶음 (제목은 가장 최근에 보낸 것) > 마친 횟수·보낸 횟수 많은 순
  private static List<RoutineSummary> toRoutineSummaries(List<Routine> routines) {
    Map<String, RoutineTally> tallyByRoutineKey = new LinkedHashMap<>();
    routines.stream()
      .sorted(Comparator.comparing(Routine::getScheduledAt))
      .forEach(routine -> tallyByRoutineKey
        .computeIfAbsent(routineKey(routine), key -> new RoutineTally())
        .add(routine));
    return tallyByRoutineKey.values().stream()
      .map(RoutineTally::toSummary)
      .sorted(Comparator.comparingInt(RoutineSummary::completedCount).reversed()
        .thenComparing(Comparator.comparingInt(RoutineSummary::sentCount).reversed()))
      .toList();
  }

  /// 지난 날(오늘 전) 마치지 않은 일과의 남은 카드 > (일과 묶음, 카드 이름)별 횟수 > 많은 순 최대 3개
  private static List<RemainingStep> toRemainingSteps(List<Routine> routines, LocalDate today) {
    Map<String, RemainingTally> tallyByStepKey = new LinkedHashMap<>();
    routines.stream()
      .filter(routine -> !isCompleted(routine) && routine.getScheduledAt().toLocalDate().isBefore(today))
      .sorted(Comparator.comparing(Routine::getScheduledAt))
      .forEach(routine -> routine.getSteps().stream()
        .filter(step -> !Boolean.TRUE.equals(step.getCompleted()))
        .forEach(step -> tallyByStepKey
          .computeIfAbsent(routineKey(routine) + "\n" + stepLabel(step),
            key -> new RemainingTally(routine.getTitle(), stepLabel(step)))
          .increase()));
    return tallyByStepKey.values().stream()
      .map(RemainingTally::toRemainingStep)
      .sorted(Comparator.comparingInt(RemainingStep::remainingCount).reversed())
      .limit(REMAINING_STEP_LIMIT)
      .toList();
  }

  /// 묶음 열쇠: 보낸 일과면 원본 ID, 원본·옛 일과면 자기 ID
  private static String routineKey(Routine routine) {
    return Objects.requireNonNullElse(routine.getSourceRoutineId(), routine.getId());
  }

  /// 카드 이름: 짧은 제목, 없으면(옛 카드) 설명
  private static String stepLabel(RoutineStep step) {
    String title = step.getTitle();
    return title == null || title.isBlank() ? step.getDescription() : title;
  }

  private static boolean isCompleted(Routine routine) {
    return routine.getStatus() == RoutineStatus.COMPLETED;
  }

  private static boolean hasReward(Routine routine) {
    return routine.getRewardText() != null && !routine.getRewardText().isBlank();
  }

  /// 일과 묶음 하나의 보낸·마친 횟수 (제목은 마지막에 더한 일과 것)
  private static final class RoutineTally {

    private String title;
    private int sentCount;
    private int completedCount;

    void add(Routine routine) {
      title = routine.getTitle();
      sentCount++;
      if (isCompleted(routine)) {
        completedCount++;
      }
    }

    RoutineSummary toSummary() {
      return new RoutineSummary(title, sentCount, completedCount);
    }
  }

  /// 남은 카드 하나의 횟수
  private static final class RemainingTally {

    private final String routineTitle;
    private final String stepTitle;
    private int remainingCount;

    RemainingTally(String routineTitle, String stepTitle) {
      this.routineTitle = routineTitle;
      this.stepTitle = stepTitle;
    }

    void increase() {
      remainingCount++;
    }

    RemainingStep toRemainingStep() {
      return new RemainingStep(routineTitle, stepTitle, remainingCount);
    }
  }
}
