package com.chuseok22.elumserver.routine.core;

import java.time.DayOfWeek;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;

/**
 * 반복 요일 묶음 > 저장 값(비트 합) 변환. 월 1 · 화 2 · 수 4 · 목 8 · 금 16 · 토 32 · 일 64
 * 요일 순서는 월요일부터 (DayOfWeek 와 같음). 그 밖의 비트는 무시
 */
public final class RoutineScheduleWeekdays {

  /// 일주일 전부 (127)
  public static final int ALL_DAYS_MASK = (1 << DayOfWeek.values().length) - 1;

  private RoutineScheduleWeekdays() {
  }

  /** 요일 목록 > 비트 합 (중복은 한 번만) */
  public static int toMask(Collection<DayOfWeek> weekdays) {
    int mask = 0;
    for (DayOfWeek weekday : weekdays) {
      mask |= bitOf(weekday);
    }
    return mask;
  }

  /** 비트 합 > 요일 목록 (월요일부터) */
  public static List<DayOfWeek> fromMask(int mask) {
    List<DayOfWeek> weekdays = new ArrayList<>();
    for (DayOfWeek weekday : DayOfWeek.values()) {
      if (isOn(mask, weekday)) {
        weekdays.add(weekday);
      }
    }
    return weekdays;
  }

  /** 이 요일이 묶음 안에 있는가 */
  public static boolean isOn(int mask, DayOfWeek weekday) {
    return (mask & bitOf(weekday)) != 0;
  }

  private static int bitOf(DayOfWeek weekday) {
    // MONDAY(1) > 1, SUNDAY(7) > 64
    return 1 << (weekday.getValue() - 1);
  }
}
