package com.chuseok22.elumserver.routine.core;

import java.time.LocalDate;
import java.util.Collection;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * 일과를 마친 날짜들 > 연속 기록 (#1409, passQL StreakCalculator 와 같은 하루 유예)
 * 시작일: 오늘 마쳤으면 오늘, 아니면 어제 (둘 다 없으면 0) > 하루씩 거슬러 이어진 날 수
 */
public final class ElumiStreakCalculator {

  private ElumiStreakCalculator() {
  }

  /// 마친 날짜(중복·순서 무관, null 무시) + 오늘 > 연속 기록
  public static ElumiStreak calculate(Collection<LocalDate> completionDates, LocalDate today) {
    if (completionDates == null || completionDates.isEmpty() || today == null) {
      return ElumiStreak.NONE;
    }
    Set<LocalDate> dates = completionDates.stream().filter(date -> date != null).collect(Collectors.toSet());
    boolean hasCompletedToday = dates.contains(today);
    LocalDate cursor = hasCompletedToday ? today : today.minusDays(1);
    int streakDays = 0;
    while (dates.contains(cursor)) {
      streakDays++;
      cursor = cursor.minusDays(1);
    }
    return new ElumiStreak(streakDays, streakDays > 0 && !hasCompletedToday);
  }
}
