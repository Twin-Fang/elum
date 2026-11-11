package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportInsightsResponse;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportInsightsResponse.HighlightKind;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportInsightsResponse.StuckSuggestion;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.function.Predicate;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 주간 인사이트 계산: 깨지면 보호자에게 없는 칭찬·잘못된 막힘 카드·틀린 시간이 리포트에 뜬다 (조건 경계마다 1건)
 */
class WeeklyReportInsightCalculatorTest {

  private static final LocalDate THIS_MONDAY = LocalDate.of(2026, 11, 9);
  private static final LocalDate LAST_MONDAY = THIS_MONDAY.minusWeeks(1);
  /// 이번 주가 모두 지난 날이 되는 기준일
  private static final LocalDate TODAY_AFTER_WEEK = THIS_MONDAY.plusWeeks(1);
  private static final Predicate<String> EVERY_LIBRARY_ROUTINE_EXISTS = id -> true;

  private static WeeklyReportInsightsResponse calculate(List<Routine> current, List<Routine> previous,
    Set<String> priorKeys, int streak) {
    return WeeklyReportInsightCalculator.calculate(streak, current, previous, priorKeys, TODAY_AFTER_WEEK,
      EVERY_LIBRARY_ROUTINE_EXISTS);
  }

  /// 카드 시각: 일과 시작(8시)부터 minutes 분 뒤 완료. null 이면 마치지 않은 카드
  private static RoutineStep step(int order, String title, Integer completedMinutesAfterStart) {
    RoutineStep step = new RoutineStep();
    step.setStepOrder(order);
    step.setTitle(title);
    step.setDescription(title + " 설명");
    step.setCompleted(completedMinutesAfterStart != null);
    if (completedMinutesAfterStart != null) {
      step.setCompletedAt(LocalDateTime.of(2026, 11, 1, 8, 0).plusMinutes(completedMinutesAfterStart));
    }
    return step;
  }

  private static Routine routine(String id, String sourceId, String title, RoutineStatus status, LocalDate date,
    RoutineStep... steps) {
    Routine routine = new Routine();
    routine.setId(id);
    routine.setSourceRoutineId(sourceId);
    routine.setTitle(title);
    routine.setStatus(status);
    routine.setScheduledAt(date.atTime(8, 0));
    routine.setSteps(new ArrayList<>(List.of(steps)));
    return routine;
  }

  private static Routine completed(String id, String sourceId, LocalDate date, RoutineStep... steps) {
    return routine(id, sourceId, "아침 준비", RoutineStatus.COMPLETED, date, steps);
  }

  private static Routine unfinished(String id, String sourceId, LocalDate date, RoutineStep... steps) {
    return routine(id, sourceId, "아침 준비", RoutineStatus.CONFIRMED, date, steps);
  }

  // --- 전체 ---

  @Test
  @DisplayName("이번 주에 보낸 일과가 없으면 인사이트 전체가 null 이다 — 빈 주에 빈 카드가 뜬다")
  void calculate_noRoutines_isNull() {
    assertThat(calculate(List.of(), List.of(), Set.of(), 0)).isNull();
  }

  // --- highlight ---

  @Test
  @DisplayName("이전 주에 끝낸 기록이 없는 일과를 이번 주 끝냈으면 FIRST_TIME_COMPLETED 다")
  void highlight_firstTimeCompleted() {
    List<Routine> current = List.of(completed("a", "lib", THIS_MONDAY, step(1, "세수", 5)));

    var highlight = calculate(current, List.of(), Set.of(), 0).highlight();

    assertThat(highlight.kind()).isEqualTo(HighlightKind.FIRST_TIME_COMPLETED);
    assertThat(highlight.routineTitle()).isEqualTo("아침 준비");
    assertThat(highlight.completedCount()).isEqualTo(1);
    assertThat(highlight.sentCount()).isEqualTo(1);
    assertThat(highlight.streakDays()).isZero();
  }

  @Test
  @DisplayName("이전 주에 이미 끝낸 일과는 처음이 아니다 — 매번 칭찬이 '처음'으로 뜬다")
  void highlight_priorCompletionIsNotFirstTime() {
    List<Routine> current = List.of(completed("a", "lib", THIS_MONDAY, step(1, "세수", 5)));

    assertThat(calculate(current, List.of(), Set.of("lib"), 0).highlight()).isNull();
  }

  @Test
  @DisplayName("원본 없는 일과는 자기 ID 로 이전 완료 여부를 가른다")
  void highlight_routineWithoutSourceUsesOwnId() {
    List<Routine> current = List.of(completed("own-id", null, THIS_MONDAY, step(1, "세수", 5)));

    assertThat(calculate(current, List.of(), Set.of("own-id"), 0).highlight()).isNull();
  }

  @Test
  @DisplayName("3번 보내 3번 다 끝내면 EVERY_TIME_COMPLETED, 2번이면 없다")
  void highlight_everyTimeNeedsThreeSends() {
    List<Routine> three = List.of(
      completed("a", "lib", THIS_MONDAY, step(1, "세수", 5)),
      completed("b", "lib", THIS_MONDAY.plusDays(1), step(1, "세수", 5)),
      completed("c", "lib", THIS_MONDAY.plusDays(2), step(1, "세수", 5)));
    List<Routine> two = three.subList(0, 2);

    assertThat(calculate(three, List.of(), Set.of("lib"), 0).highlight().kind())
      .isEqualTo(HighlightKind.EVERY_TIME_COMPLETED);
    assertThat(calculate(two, List.of(), Set.of("lib"), 0).highlight()).isNull();
  }

  @Test
  @DisplayName("한 번이라도 못 끝낸 일과는 EVERY_TIME_COMPLETED 가 아니다")
  void highlight_everyTimeNeedsAllCompleted() {
    List<Routine> current = List.of(
      completed("a", "lib", THIS_MONDAY, step(1, "세수", 5)),
      completed("b", "lib", THIS_MONDAY.plusDays(1), step(1, "세수", 5)),
      unfinished("c", "lib", THIS_MONDAY.plusDays(2), step(1, "세수", null)));

    assertThat(calculate(current, List.of(), Set.of("lib"), 0).highlight()).isNull();
  }

  @Test
  @DisplayName("매번 끝낸 일과가 여럿이면 가장 많이 보낸 것이 뽑힌다")
  void highlight_everyTimePicksMostSent() {
    List<Routine> current = new ArrayList<>();
    for (int day = 0; day < 3; day++) {
      current.add(routine("s" + day, "small", "양치", RoutineStatus.COMPLETED, THIS_MONDAY.plusDays(day), step(1, "칫솔", 1)));
    }
    for (int day = 0; day < 4; day++) {
      current.add(routine("b" + day, "big", "잠자기", RoutineStatus.COMPLETED, THIS_MONDAY.plusDays(day), step(1, "불 끄기", 1)));
    }

    assertThat(calculate(current, List.of(), Set.of("small", "big"), 0).highlight().routineTitle()).isEqualTo("잠자기");
  }

  @Test
  @DisplayName("끝낸 날이 3일 이어지면 LONGEST_STREAK 와 일수, 2일이면 없다")
  void highlight_streakNeedsThreeDays() {
    List<Routine> current = List.of(
      completed("a", "lib", THIS_MONDAY, step(1, "세수", 5)),
      unfinished("b", "lib", THIS_MONDAY.plusDays(1), step(1, "세수", null)));

    var streak = calculate(current, List.of(), Set.of("lib"), 3).highlight();

    assertThat(streak.kind()).isEqualTo(HighlightKind.LONGEST_STREAK);
    assertThat(streak.streakDays()).isEqualTo(3);
    assertThat(streak.routineTitle()).isNull();
    assertThat(calculate(current, List.of(), Set.of("lib"), 2).highlight()).isNull();
  }

  // --- stuck ---

  private static List<Routine> sentThreeTimes(int unfinishedCount, RoutineStep unfinishedStep) {
    List<Routine> routines = new ArrayList<>();
    for (int day = 0; day < 3; day++) {
      LocalDate date = THIS_MONDAY.plusDays(day);
      routines.add(day < unfinishedCount
        ? unfinished("r" + day, "lib", date, step(1, "세수", 2), copyOf(unfinishedStep))
        : completed("r" + day, "lib", date, step(1, "세수", 2), step(2, "양치하기", 4)));
    }
    return routines;
  }

  private static RoutineStep copyOf(RoutineStep source) {
    RoutineStep copy = step(source.getStepOrder(), source.getTitle(), null);
    copy.setGuardianVoicePath(source.getGuardianVoicePath());
    copy.setImagePath(source.getImagePath());
    return copy;
  }

  @Test
  @DisplayName("3번 보낸 일과에서 같은 카드가 2번 남으면 stuck 이고 목소리·사진이 없으면 ADD_VOICE_OR_PHOTO 다")
  void stuck_threeSendsTwoRemained() {
    var stuck = calculate(sentThreeTimes(2, step(2, "양치하기", null)), List.of(), Set.of("lib"), 0).stuck();

    assertThat(stuck.libraryRoutineId()).isEqualTo("lib");
    assertThat(stuck.routineTitle()).isEqualTo("아침 준비");
    assertThat(stuck.stepTitle()).isEqualTo("양치하기");
    assertThat(stuck.stepOrder()).isEqualTo(2);
    assertThat(stuck.remainedCount()).isEqualTo(2);
    assertThat(stuck.sentCount()).isEqualTo(3);
    assertThat(stuck.suggestion()).isEqualTo(StuckSuggestion.ADD_VOICE_OR_PHOTO);
  }

  @Test
  @DisplayName("카드에 보호자 목소리가 있으면 제안은 SHORTEN_OR_SPLIT 이다 — 이미 있는 목소리를 또 권한다")
  void stuck_withGuardianVoiceSuggestsShorten() {
    RoutineStep voiced = step(2, "양치하기", null);
    voiced.setGuardianVoicePath("m1/voice.m4a");

    var stuck = calculate(sentThreeTimes(2, voiced), List.of(), Set.of("lib"), 0).stuck();

    assertThat(stuck.suggestion()).isEqualTo(StuckSuggestion.SHORTEN_OR_SPLIT);
  }

  @Test
  @DisplayName("2번만 보낸 일과, 1번만 남은 카드는 stuck 이 아니다 — 우연한 하루가 문제 카드로 뜬다")
  void stuck_belowThresholdsIsNull() {
    List<Routine> sentTwice = sentThreeTimes(2, step(2, "양치하기", null)).subList(0, 2);

    assertThat(calculate(sentTwice, List.of(), Set.of("lib"), 0).stuck()).isNull();
    assertThat(calculate(sentThreeTimes(1, step(2, "양치하기", null)), List.of(), Set.of("lib"), 0).stuck()).isNull();
  }

  @Test
  @DisplayName("오늘 진행 중인 일과에 남은 카드는 세지 않는다 — 아직 하는 중인 카드가 막힘으로 뜬다")
  void stuck_ignoresTodayRoutine() {
    List<Routine> routines = sentThreeTimes(2, step(2, "양치하기", null));
    LocalDate today = THIS_MONDAY.plusDays(1);

    var insights = WeeklyReportInsightCalculator.calculate(0, routines, List.of(), Set.of("lib"), today,
      EVERY_LIBRARY_ROUTINE_EXISTS);

    assertThat(insights.stuck()).isNull();
  }

  @Test
  @DisplayName("원본 일과가 지워졌으면 libraryRoutineId 는 null 이다 — 없는 일과로 가는 링크가 생긴다")
  void stuck_deletedLibraryRoutineHasNullId() {
    var insights = WeeklyReportInsightCalculator.calculate(0, sentThreeTimes(2, step(2, "양치하기", null)),
      List.of(), Set.of("lib"), TODAY_AFTER_WEEK, id -> false);

    assertThat(insights.stuck().libraryRoutineId()).isNull();
  }

  // --- trend ---

  @Test
  @DisplayName("지난주에 보낸 일과가 없으면 trend 는 null, 있으면 두 주 끝낸 일과 수다")
  void trend_requiresPreviousWeekRoutines() {
    List<Routine> current = List.of(
      completed("a", "lib", THIS_MONDAY, step(1, "세수", 5)),
      completed("b", "lib", THIS_MONDAY.plusDays(1), step(1, "세수", 5)));
    List<Routine> previous = List.of(
      completed("p1", "lib", LAST_MONDAY, step(1, "세수", 5)),
      unfinished("p2", "lib", LAST_MONDAY.plusDays(1), step(1, "세수", null)));

    assertThat(calculate(current, List.of(), Set.of(), 0).trend()).isNull();
    var trend = calculate(current, previous, Set.of(), 0).trend();
    assertThat(trend.previousCompletedRoutineCount()).isEqualTo(1);
    assertThat(trend.currentCompletedRoutineCount()).isEqualTo(2);
  }

  // --- duration ---

  private static Routine takingMinutes(String id, LocalDate date, int minutes) {
    return completed(id, "lib", date, step(1, "세수", 0), step(2, "양치하기", minutes));
  }

  @Test
  @DisplayName("두 주 모두 2번 끝낸 일과는 평균 걸린 시간을 비교한다")
  void duration_comparesAverages() {
    List<Routine> previous = List.of(takingMinutes("p1", LAST_MONDAY, 16), takingMinutes("p2", LAST_MONDAY.plusDays(1), 20));
    List<Routine> current = List.of(takingMinutes("c1", THIS_MONDAY, 10), takingMinutes("c2", THIS_MONDAY.plusDays(1), 14));

    var duration = calculate(current, previous, Set.of("lib"), 0).duration();

    assertThat(duration.routineTitle()).isEqualTo("아침 준비");
    assertThat(duration.previousAverageMinutes()).isEqualTo(18);
    assertThat(duration.currentAverageMinutes()).isEqualTo(12);
  }

  @Test
  @DisplayName("한 주에 1번만 끝냈으면 duration 은 null 이다 — 한 번의 기록이 추세로 뜬다")
  void duration_needsTwoCompletionsEachWeek() {
    List<Routine> previous = List.of(takingMinutes("p1", LAST_MONDAY, 16), takingMinutes("p2", LAST_MONDAY.plusDays(1), 20));
    List<Routine> current = List.of(takingMinutes("c1", THIS_MONDAY, 10));

    assertThat(calculate(current, previous, Set.of("lib"), 0).duration()).isNull();
  }

  @Test
  @DisplayName("120분 넘는 기록은 평균에서 빠진다 — 중간에 쉰 기록이 평균을 망친다")
  void duration_excludesOverTwoHours() {
    List<Routine> previous = List.of(
      takingMinutes("p1", LAST_MONDAY, 16), takingMinutes("p2", LAST_MONDAY.plusDays(1), 20),
      takingMinutes("p3", LAST_MONDAY.plusDays(2), 121));
    List<Routine> current = List.of(takingMinutes("c1", THIS_MONDAY, 10), takingMinutes("c2", THIS_MONDAY.plusDays(1), 14));

    assertThat(calculate(current, previous, Set.of("lib"), 0).duration().previousAverageMinutes()).isEqualTo(18);
  }

  @Test
  @DisplayName("두 주 평균이 같으면 duration 은 null 이다")
  void duration_equalAveragesIsNull() {
    List<Routine> previous = List.of(takingMinutes("p1", LAST_MONDAY, 12), takingMinutes("p2", LAST_MONDAY.plusDays(1), 12));
    List<Routine> current = List.of(takingMinutes("c1", THIS_MONDAY, 12), takingMinutes("c2", THIS_MONDAY.plusDays(1), 12));

    assertThat(calculate(current, previous, Set.of("lib"), 0).duration()).isNull();
  }

  // --- slowestStep ---

  private static Routine withStepGaps(String id, LocalDate date, int firstGap, int secondGap) {
    return completed(id, "lib", date, step(1, "세수", 0), step(2, "양치하기", firstGap), step(3, "옷 입기", firstGap + secondGap));
  }

  @Test
  @DisplayName("이웃한 카드 간격 평균이 가장 긴 카드가 slowestStep 이다 (간격은 뒤 카드에 모은다)")
  void slowestStep_picksLongestAverageGap() {
    List<Routine> current = List.of(withStepGaps("a", THIS_MONDAY, 4, 1), withStepGaps("b", THIS_MONDAY.plusDays(1), 4, 3));

    var slowest = calculate(current, List.of(), Set.of("lib"), 0).slowestStep();

    assertThat(slowest.stepTitle()).isEqualTo("양치하기");
    assertThat(slowest.routineTitle()).isEqualTo("아침 준비");
    assertThat(slowest.averageMinutes()).isEqualTo(4);
  }

  @Test
  @DisplayName("표본이 1개뿐이면 slowestStep 은 null 이다")
  void slowestStep_needsTwoSamples() {
    List<Routine> current = List.of(withStepGaps("a", THIS_MONDAY, 4, 1));

    assertThat(calculate(current, List.of(), Set.of("lib"), 0).slowestStep()).isNull();
  }

  @Test
  @DisplayName("60분 넘는 간격은 빠지고, 평균이 1분 미만이면 slowestStep 은 null 이다 — 쉰 시간이나 순간 간격이 '오래 걸림'으로 뜬다")
  void slowestStep_excludesLongGapsAndSubMinuteAverage() {
    List<Routine> overOneHour = List.of(withStepGaps("a", THIS_MONDAY, 61, 0), withStepGaps("b", THIS_MONDAY.plusDays(1), 61, 0));
    List<Routine> subMinute = List.of(
      completed("c", "lib", THIS_MONDAY, step(1, "세수", 0), step(2, "양치하기", 0)),
      completed("d", "lib", THIS_MONDAY.plusDays(1), step(1, "세수", 0), step(2, "양치하기", 0)));

    assertThat(calculate(overOneHour, List.of(), Set.of("lib"), 0).slowestStep()).isNull();
    assertThat(calculate(subMinute, List.of(), Set.of("lib"), 0).slowestStep()).isNull();
  }
}
