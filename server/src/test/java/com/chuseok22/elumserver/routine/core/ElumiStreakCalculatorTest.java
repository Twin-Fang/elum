package com.chuseok22.elumserver.routine.core;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 연속 기록이 틀리면 보호자 홈 불꽃 숫자가 틀리고, 끊길 때 알림(STREAK_AT_RISK)이 엉뚱한 사람에게 간다 (#1409)
class ElumiStreakCalculatorTest {

  private static final LocalDate TODAY = LocalDate.of(2026, 11, 14);

  @Test
  @DisplayName("마친 날이 없으면 0, 끊길 걱정도 없음")
  void noCompletion_isZero() {
    assertThat(ElumiStreakCalculator.calculate(List.of(), TODAY)).isEqualTo(ElumiStreak.NONE);
    assertThat(ElumiStreakCalculator.calculate(null, TODAY)).isEqualTo(ElumiStreak.NONE);
  }

  @Test
  @DisplayName("오늘까지 이어졌으면 오늘 포함 일수, 오늘 마쳤으니 끊길 걱정 없음")
  void continuousUntilToday_countsTodayAndNotAtRisk() {
    ElumiStreak streak = ElumiStreakCalculator.calculate(
      List.of(TODAY, TODAY.minusDays(1), TODAY.minusDays(2)), TODAY);

    assertThat(streak).isEqualTo(new ElumiStreak(3, false));
  }

  @Test
  @DisplayName("하루 유예: 오늘 아직 안 마쳤어도 어제까지 이어졌으면 일수 유지 + 오늘 끊길 수 있음")
  void untilYesterday_keepsStreakAndIsAtRisk() {
    ElumiStreak streak = ElumiStreakCalculator.calculate(List.of(TODAY.minusDays(1), TODAY.minusDays(2)), TODAY);

    assertThat(streak).isEqualTo(new ElumiStreak(2, true));
  }

  @Test
  @DisplayName("그저께가 마지막이면 이미 끊김: 0 (유예는 하루만)")
  void lastCompletionTwoDaysAgo_isBroken() {
    assertThat(ElumiStreakCalculator.calculate(List.of(TODAY.minusDays(2), TODAY.minusDays(3)), TODAY))
      .isEqualTo(ElumiStreak.NONE);
  }

  @Test
  @DisplayName("중간에 빈 날이 있으면 그 앞에서 멈춤")
  void gap_stopsCounting() {
    ElumiStreak streak = ElumiStreakCalculator.calculate(
      List.of(TODAY, TODAY.minusDays(1), TODAY.minusDays(3), TODAY.minusDays(4)), TODAY);

    assertThat(streak.currentStreakDays()).isEqualTo(2);
  }

  @Test
  @DisplayName("하루에 여러 번 마친 것·순서·null 은 기록에 영향 없음")
  void duplicatesOrderAndNull_areIgnored() {
    List<LocalDate> dates = new ArrayList<>(List.of(TODAY.minusDays(1), TODAY.minusDays(2), TODAY.minusDays(1)));
    dates.add(null);

    assertThat(ElumiStreakCalculator.calculate(dates, TODAY)).isEqualTo(new ElumiStreak(2, true));
  }

  @Test
  @DisplayName("오늘 처음 마쳤으면 1일, 끊길 걱정 없음")
  void firstCompletionToday_isOne() {
    assertThat(ElumiStreakCalculator.calculate(List.of(TODAY), TODAY)).isEqualTo(new ElumiStreak(1, false));
  }
}
