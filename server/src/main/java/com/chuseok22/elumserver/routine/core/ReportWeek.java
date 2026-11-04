package com.chuseok22.elumserver.routine.core;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.TemporalAdjusters;
import java.util.List;
import java.util.stream.IntStream;

/**
 * 주간 리포트 한 주: 월요일 0시 ~ 다음 월요일 0시 (끝 미포함)
 * 크레딧 주기(CreditPeriod)와 같은 월요일 시작 · 시스템 시간대(운영 TZ=Asia/Seoul) 기준
 */
public record ReportWeek(LocalDate start) {

  /// 한 주 일수
  public static final int DAYS_PER_WEEK = 7;

  /// 아무 날짜 > 그 날이 든 주 (월요일로 맞춤)
  public static ReportWeek containing(LocalDate date) {
    return new ReportWeek(date.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY)));
  }

  /// 마지막 날 (일요일, 포함)
  public LocalDate lastDay() {
    return start.plusDays(DAYS_PER_WEEK - 1L);
  }

  public LocalDateTime startAt() {
    return start.atStartOfDay();
  }

  /// 조회 끝 시각 (다음 월요일 0시 직전) — Between 조회가 끝을 포함하므로 1나노 뺀다
  public LocalDateTime lastMoment() {
    return start.plusDays(DAYS_PER_WEEK).atStartOfDay().minusNanos(1);
  }

  /// 월 ~ 일 7일
  public List<LocalDate> days() {
    return IntStream.range(0, DAYS_PER_WEEK).mapToObj(start::plusDays).toList();
  }

  public boolean isAfter(ReportWeek other) {
    return start.isAfter(other.start);
  }
}
