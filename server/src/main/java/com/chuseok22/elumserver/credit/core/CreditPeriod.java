package com.chuseok22.elumserver.credit.core;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.IsoFields;
import java.time.temporal.TemporalAdjusters;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * 지급 주기 하나. 끝은 포함하지 않는다. 주기 계산은 이 클래스 한 곳에서만 한다.
 *
 * <p>WEEK: 월요일 0시 ~ 다음 월요일 0시, key 는 ISO 주({@code 2026-W39}). V26 이 Postgres
 * {@code to_char(..., 'IYYY-"W"IW')} 로 같은 값을 만든다 — 어긋나면 마이그레이션이 준 이번 주 지급을 코드가 못 찾아
 * 한 번 더 준다. 연말 주는 ISO 주 연도를 쓴다(2027-01-01 은 2026-W53).
 *
 * <p>MONTH: 1일 0시 ~ 다음 달 1일 0시, key 는 {@code 2026-M11} (period_key 길이 10 안, 주 키와 겹치지 않음).
 *
 * <p>시각은 시스템 기본 시간대 기준이다 — 운영 컨테이너가 TZ=Asia/Seoul 이라 한국 시각이다.
 */
public record CreditPeriod(String key, LocalDateTime start, LocalDateTime end, CreditPeriodUnit unit) {

  private static final Pattern PERIOD_KEY = Pattern.compile("(\\d{4})-([WM])(\\d{2})");

  /// 주 단위 주기 (단위를 고르지 않는 곳 전용)
  public static CreditPeriod of(LocalDateTime now) {
    return of(CreditPeriodUnit.WEEK, now);
  }

  /// 단위 + 시각 > 그 시각이 든 주기
  public static CreditPeriod of(CreditPeriodUnit unit, LocalDateTime now) {
    return switch (unit) {
      case WEEK -> weekContaining(now);
      case MONTH -> monthContaining(now);
    };
  }

  private static CreditPeriod weekContaining(LocalDateTime now) {
    LocalDateTime start = now.toLocalDate()
      .with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
      .atStartOfDay();
    String key = "%d-W%02d".formatted(
      start.get(IsoFields.WEEK_BASED_YEAR), start.get(IsoFields.WEEK_OF_WEEK_BASED_YEAR));
    return new CreditPeriod(key, start, start.plusWeeks(1), CreditPeriodUnit.WEEK);
  }

  private static CreditPeriod monthContaining(LocalDateTime now) {
    LocalDateTime start = now.toLocalDate().withDayOfMonth(1).atStartOfDay();
    String key = "%d-M%02d".formatted(start.getYear(), start.getMonthValue());
    return new CreditPeriod(key, start, start.plusMonths(1), CreditPeriodUnit.MONTH);
  }

  /// 주기 키({@code 2026-W39} · {@code 2026-M11}) > 주기. 형식이 틀리거나 없는 주·달이면 비어 있음
  public static Optional<CreditPeriod> fromKey(String key) {
    if (key == null) {
      return Optional.empty();
    }
    Matcher matcher = PERIOD_KEY.matcher(key.trim());
    if (!matcher.matches()) {
      return Optional.empty();
    }
    try {
      int year = Integer.parseInt(matcher.group(1));
      int number = Integer.parseInt(matcher.group(3));
      if (matcher.group(2).charAt(0) == CreditPeriodUnit.MONTH.getKeyMarker()) {
        return Optional.of(monthContaining(LocalDate.of(year, number, 1).atStartOfDay()));
      }
      // ISO 주 연도의 1월 4일은 언제나 그 해 첫 주에 있다.
      LocalDate monday = LocalDate.of(year, 1, 4)
        .with(IsoFields.WEEK_OF_WEEK_BASED_YEAR, number)
        .with(DayOfWeek.MONDAY);
      return Optional.of(weekContaining(monday.atStartOfDay()));
    } catch (RuntimeException e) {
      return Optional.empty();
    }
  }

  /// 바로 앞 주기 (같은 단위)
  public CreditPeriod previous() {
    return of(unit, start.minusDays(1));
  }

  /// 바로 다음 주기 (같은 단위)
  public CreditPeriod next() {
    return of(unit, end);
  }

  public boolean contains(LocalDateTime at) {
    return !at.isBefore(start) && at.isBefore(end);
  }

  /// 같은 단위의 다른 주기 키인가 (단위가 다른 키는 전환 전 지급이라 false)
  public boolean isOtherPeriodKeyOfSameUnit(String periodKey) {
    return periodKey != null && !key.equals(periodKey)
      && CreditPeriodUnit.fromPeriodKey(periodKey).filter(unit::equals).isPresent();
  }
}
