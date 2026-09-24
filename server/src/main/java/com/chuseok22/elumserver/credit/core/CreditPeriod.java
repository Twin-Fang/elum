package com.chuseok22.elumserver.credit.core;

import java.time.DayOfWeek;
import java.time.LocalDateTime;
import java.time.temporal.IsoFields;
import java.time.temporal.TemporalAdjusters;

/**
 * 주간 지급 주기 하나 (#407). 월요일 0시에 시작해 다음 월요일 0시에 끝난다(끝은 포함하지 않는다).
 *
 * <p>key 는 ISO 주({@code 2026-W39})다. V26 이 Postgres {@code to_char(..., 'IYYY-"W"IW')} 로 같은 값을
 * 만든다 — 둘이 어긋나면 마이그레이션이 준 이번 주 지급을 코드가 못 찾아 한 번 더 준다.
 * 연말 주는 달력 연도가 아니라 ISO 주 연도를 쓴다(2027-01-01 은 2026-W53).
 *
 * <p>시각은 시스템 기본 시간대 기준이다 — 운영 컨테이너가 TZ=Asia/Seoul 이라 한국 시각 월요일 0시다.
 */
public record CreditPeriod(String key, LocalDateTime start, LocalDateTime end) {

  public static CreditPeriod of(LocalDateTime now) {
    LocalDateTime start = now.toLocalDate()
      .with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
      .atStartOfDay();
    String key = "%d-W%02d".formatted(
      start.get(IsoFields.WEEK_BASED_YEAR), start.get(IsoFields.WEEK_OF_WEEK_BASED_YEAR));
    return new CreditPeriod(key, start, start.plusWeeks(1));
  }

  public boolean contains(LocalDateTime at) {
    return !at.isBefore(start) && at.isBefore(end);
  }
}
