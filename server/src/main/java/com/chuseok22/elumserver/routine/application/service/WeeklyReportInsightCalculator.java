package com.chuseok22.elumserver.routine.application.service;

import static com.chuseok22.elumserver.routine.application.service.WeeklyReportAggregator.isCompleted;
import static com.chuseok22.elumserver.routine.application.service.WeeklyReportAggregator.routineKey;
import static com.chuseok22.elumserver.routine.application.service.WeeklyReportAggregator.stepLabel;

import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportInsightsResponse;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportInsightsResponse.Duration;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportInsightsResponse.Highlight;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportInsightsResponse.HighlightKind;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportInsightsResponse.SlowestStep;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportInsightsResponse.Stuck;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportInsightsResponse.StuckSuggestion;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportInsightsResponse.Trend;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.function.Predicate;

/**
 * 한 주 일과 목록 > 주간 인사이트 5칸 (DB 없음, 순수 계산)
 * 칭찬 거리, 자주 남은 카드, 지난주 대비, 걸린 시간 변화, 가장 오래 걸린 카드
 */
final class WeeklyReportInsightCalculator {

  /// 칭찬·막힘 판단에 필요한 그 주 최소 발송 횟수
  static final int MINIMUM_SENT_COUNT = 3;
  /// 막힘 판단에 필요한 카드 최소 남은 횟수
  static final int MINIMUM_REMAINED_COUNT = 2;
  /// 연속 칭찬에 필요한 최소 연속 일수
  static final int MINIMUM_STREAK_DAYS = 3;
  /// 걸린 시간 비교에 필요한 주당 최소 완료 횟수
  static final int MINIMUM_DURATION_SAMPLE_COUNT = 2;
  /// 일과 하나 걸린 시간 상한 (분) — 넘는 기록은 중간에 쉰 것으로 보고 뺌
  static final long MAXIMUM_ROUTINE_MINUTES = 120;
  /// 카드 사이 간격 상한 (분) — 넘는 간격은 뺌
  static final long MAXIMUM_STEP_GAP_MINUTES = 60;
  /// 카드 간격 평균에 필요한 최소 표본 수
  static final int MINIMUM_STEP_GAP_SAMPLE_COUNT = 2;
  private static final long SECONDS_PER_MINUTE = 60;

  private WeeklyReportInsightCalculator() {
  }

  /**
   * currentRoutines·previousRoutines: 이번 주·지난주에 보낸 일과(복사본 제외, 카드 포함)
   * priorCompletedKeys: 이번 주 전에 끝낸 적 있는 일과 묶음 열쇠
   * isLibraryRoutineExisting: 원본 일과가 아직 있나 (막힘 카드가 있을 때만 호출)
   */
  static WeeklyReportInsightsResponse calculate(int longestCompletedDayStreak, List<Routine> currentRoutines,
    List<Routine> previousRoutines, Set<String> priorCompletedKeys, LocalDate today,
    Predicate<String> isLibraryRoutineExisting) {
    if (currentRoutines.isEmpty()) {
      return null;
    }
    Map<String, WeeklyReportRoutineGroup> currentGroups = groupByRoutineKey(currentRoutines);
    Map<String, WeeklyReportRoutineGroup> previousGroups = groupByRoutineKey(previousRoutines);
    return new WeeklyReportInsightsResponse(
      findHighlight(currentGroups, priorCompletedKeys, longestCompletedDayStreak, currentRoutines),
      findStuck(currentGroups, today, isLibraryRoutineExisting),
      findTrend(currentRoutines, previousRoutines),
      findDuration(currentGroups, previousGroups),
      findSlowestStep(currentGroups)
    );
  }

  /// 처음 끝까지 함 > 매번 끝까지 함 > 연속 기록 (먼저 맞는 것 하나)
  private static Highlight findHighlight(Map<String, WeeklyReportRoutineGroup> groups, Set<String> priorCompletedKeys,
    int longestCompletedDayStreak, List<Routine> routines) {
    Optional<WeeklyReportRoutineGroup> firstTime = groups.entrySet().stream()
      .filter(entry -> entry.getValue().completedCount > 0 && !priorCompletedKeys.contains(entry.getKey()))
      .map(Map.Entry::getValue)
      .max(Comparator.comparingInt((WeeklyReportRoutineGroup group) -> group.completedCount));
    if (firstTime.isPresent()) {
      return toHighlight(HighlightKind.FIRST_TIME_COMPLETED, firstTime.get());
    }
    Optional<WeeklyReportRoutineGroup> everyTime = groups.values().stream()
      .filter(group -> group.sentCount >= MINIMUM_SENT_COUNT && group.completedCount == group.sentCount)
      .max(Comparator.comparingInt((WeeklyReportRoutineGroup group) -> group.sentCount));
    if (everyTime.isPresent()) {
      return toHighlight(HighlightKind.EVERY_TIME_COMPLETED, everyTime.get());
    }
    if (longestCompletedDayStreak >= MINIMUM_STREAK_DAYS) {
      int completedCount = (int) routines.stream().filter(WeeklyReportAggregator::isCompleted).count();
      return new Highlight(HighlightKind.LONGEST_STREAK, null, completedCount, routines.size(),
        longestCompletedDayStreak);
    }
    return null;
  }

  private static Highlight toHighlight(HighlightKind kind, WeeklyReportRoutineGroup group) {
    return new Highlight(kind, group.title, group.completedCount, group.sentCount, 0);
  }

  /// 지난 날 끝내지 않은 카드를 (일과 묶음, 카드 이름)별로 세어 가장 자주 남은 것 (오늘 일과는 진행 중이라 제외)
  private static Stuck findStuck(Map<String, WeeklyReportRoutineGroup> groups, LocalDate today,
    Predicate<String> isLibraryRoutineExisting) {
    Stuck best = null;
    int bestRemainedCount = 0;
    for (WeeklyReportRoutineGroup group : groups.values()) {
      if (group.sentCount < MINIMUM_SENT_COUNT) {
        continue;
      }
      for (RemainedCard card : countRemainedCards(group, today).values()) {
        if (card.remainedCount >= MINIMUM_REMAINED_COUNT && card.remainedCount > bestRemainedCount) {
          bestRemainedCount = card.remainedCount;
          best = toStuck(group, card, isLibraryRoutineExisting);
        }
      }
    }
    return best;
  }

  private static Map<String, RemainedCard> countRemainedCards(WeeklyReportRoutineGroup group, LocalDate today) {
    Map<String, RemainedCard> cardByLabel = new LinkedHashMap<>();
    for (Routine routine : group.routines) {
      boolean isPastUnfinished = !isCompleted(routine) && routine.getScheduledAt().toLocalDate().isBefore(today);
      if (!isPastUnfinished) {
        continue;
      }
      for (RoutineStep step : routine.getSteps()) {
        if (!Boolean.TRUE.equals(step.getCompleted())) {
          cardByLabel.computeIfAbsent(stepLabel(step), label -> new RemainedCard()).add(routine, step);
        }
      }
    }
    return cardByLabel;
  }

  private static Stuck toStuck(WeeklyReportRoutineGroup group, RemainedCard card, Predicate<String> isLibraryRoutineExisting) {
    String sourceRoutineId = card.latestRoutine.getSourceRoutineId();
    boolean hasLibraryRoutine = sourceRoutineId != null && isLibraryRoutineExisting.test(sourceRoutineId);
    boolean hasVoiceOrPhoto = hasText(card.latestStep.getGuardianVoicePath())
      || RoutineImageStorage.isGuardianUploadedPhoto(card.latestStep.getImagePath());
    return new Stuck(
      hasLibraryRoutine ? sourceRoutineId : null,
      group.title,
      stepLabel(card.latestStep),
      card.latestStep.getStepOrder(),
      card.remainedCount,
      group.sentCount,
      hasVoiceOrPhoto ? StuckSuggestion.SHORTEN_OR_SPLIT : StuckSuggestion.ADD_VOICE_OR_PHOTO
    );
  }

  /// 지난주에 보낸 일과가 있을 때만 두 주 끝낸 일과 수
  private static Trend findTrend(List<Routine> currentRoutines, List<Routine> previousRoutines) {
    if (previousRoutines.isEmpty()) {
      return null;
    }
    return new Trend(countCompleted(previousRoutines), countCompleted(currentRoutines));
  }

  /// 두 주 모두 2번 이상 끝낸 일과 중 이번 주 가장 많이 한 것의 평균 걸린 시간 (같으면 null)
  private static Duration findDuration(Map<String, WeeklyReportRoutineGroup> currentGroups,
    Map<String, WeeklyReportRoutineGroup> previousGroups) {
    Duration best = null;
    int bestCurrentSampleCount = 0;
    for (Map.Entry<String, WeeklyReportRoutineGroup> entry : currentGroups.entrySet()) {
      WeeklyReportRoutineGroup previousGroup = previousGroups.get(entry.getKey());
      if (previousGroup == null) {
        continue;
      }
      List<Long> currentSeconds = measureRoutineSeconds(entry.getValue());
      List<Long> previousSeconds = measureRoutineSeconds(previousGroup);
      boolean hasEnoughSamples = currentSeconds.size() >= MINIMUM_DURATION_SAMPLE_COUNT
        && previousSeconds.size() >= MINIMUM_DURATION_SAMPLE_COUNT;
      if (!hasEnoughSamples || currentSeconds.size() <= bestCurrentSampleCount) {
        continue;
      }
      int previousMinutes = toRoundedMinutes(average(previousSeconds));
      int currentMinutes = toRoundedMinutes(average(currentSeconds));
      if (previousMinutes != currentMinutes) {
        bestCurrentSampleCount = currentSeconds.size();
        best = new Duration(entry.getValue().title, previousMinutes, currentMinutes);
      }
    }
    return best;
  }

  /// 끝낸 일과마다 첫 카드 ~ 마지막 카드 완료 시각 간격(초). 카드 시각이 2개 미만이거나 120분 넘으면 뺌
  private static List<Long> measureRoutineSeconds(WeeklyReportRoutineGroup group) {
    List<Long> secondsList = new ArrayList<>();
    for (Routine routine : group.routines) {
      if (!isCompleted(routine)) {
        continue;
      }
      List<LocalDateTime> completedAts = routine.getSteps().stream()
        .map(RoutineStep::getCompletedAt)
        .filter(Objects::nonNull)
        .sorted()
        .toList();
      if (completedAts.size() < 2) {
        continue;
      }
      long seconds = secondsBetween(completedAts.get(0), completedAts.get(completedAts.size() - 1));
      if (seconds <= MAXIMUM_ROUTINE_MINUTES * SECONDS_PER_MINUTE) {
        secondsList.add(seconds);
      }
    }
    return secondsList;
  }

  /// 이웃한 두 카드 완료 간격을 뒤 카드에 모아 평균이 가장 긴 카드 (표본 2개 이상, 60분 넘는 간격 제외, 1분 미만이면 null)
  private static SlowestStep findSlowestStep(Map<String, WeeklyReportRoutineGroup> groups) {
    SlowestStep best = null;
    double bestAverageSeconds = 0;
    for (WeeklyReportRoutineGroup group : groups.values()) {
      for (Map.Entry<String, List<Long>> entry : collectStepGapSeconds(group).entrySet()) {
        double averageSeconds = average(entry.getValue());
        boolean isSlowerAndMeasurable = entry.getValue().size() >= MINIMUM_STEP_GAP_SAMPLE_COUNT
          && averageSeconds >= SECONDS_PER_MINUTE && averageSeconds > bestAverageSeconds;
        if (isSlowerAndMeasurable) {
          bestAverageSeconds = averageSeconds;
          best = new SlowestStep(group.title, entry.getKey(), toRoundedMinutes(averageSeconds));
        }
      }
    }
    return best;
  }

  private static Map<String, List<Long>> collectStepGapSeconds(WeeklyReportRoutineGroup group) {
    Map<String, List<Long>> gapSecondsByStepLabel = new LinkedHashMap<>();
    for (Routine routine : group.routines) {
      List<RoutineStep> steps = routine.getSteps().stream()
        .sorted(Comparator.comparing(RoutineStep::getStepOrder))
        .toList();
      for (int index = 1; index < steps.size(); index++) {
        LocalDateTime previousAt = steps.get(index - 1).getCompletedAt();
        LocalDateTime currentAt = steps.get(index).getCompletedAt();
        if (previousAt == null || currentAt == null) {
          continue;
        }
        long gapSeconds = secondsBetween(previousAt, currentAt);
        boolean isMeasurableGap = gapSeconds >= 0 && gapSeconds <= MAXIMUM_STEP_GAP_MINUTES * SECONDS_PER_MINUTE;
        if (isMeasurableGap) {
          gapSecondsByStepLabel.computeIfAbsent(stepLabel(steps.get(index)), label -> new ArrayList<>()).add(gapSeconds);
        }
      }
    }
    return gapSecondsByStepLabel;
  }

  private static Map<String, WeeklyReportRoutineGroup> groupByRoutineKey(List<Routine> routines) {
    Map<String, WeeklyReportRoutineGroup> groupByKey = new LinkedHashMap<>();
    routines.stream()
      .sorted(Comparator.comparing(Routine::getScheduledAt))
      .forEach(routine -> groupByKey.computeIfAbsent(routineKey(routine), key -> new WeeklyReportRoutineGroup()).add(routine));
    return groupByKey;
  }

  private static int countCompleted(List<Routine> routines) {
    return (int) routines.stream().filter(WeeklyReportAggregator::isCompleted).count();
  }

  private static long secondsBetween(LocalDateTime from, LocalDateTime to) {
    return java.time.Duration.between(from, to).getSeconds();
  }

  private static double average(List<Long> values) {
    return values.stream().mapToLong(Long::longValue).average().orElse(0);
  }

  private static int toRoundedMinutes(double seconds) {
    return (int) Math.round(seconds / SECONDS_PER_MINUTE);
  }

  private static boolean hasText(String value) {
    return value != null && !value.isBlank();
  }

  /// 남은 카드 하나: 남은 횟수와 가장 최근에 남은 일과·카드
  private static final class RemainedCard {

    private Routine latestRoutine;
    private RoutineStep latestStep;
    private int remainedCount;

    void add(Routine routine, RoutineStep step) {
      latestRoutine = routine;
      latestStep = step;
      remainedCount++;
    }
  }
}
