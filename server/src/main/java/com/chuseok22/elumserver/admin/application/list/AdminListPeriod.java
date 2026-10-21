package com.chuseok22.elumserver.admin.application.list;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * 목록 기간 필터 공통(from, to): 보정, 시작(포함)·끝(미포함) 시각
 * 기본 최근 N일(AdminListDefaults.DEFAULT_PERIOD_DAYS, 오늘 포함), 범위 밖·역전 날짜는 보정
 */
public final class AdminListPeriod {

  /// 필터 키: 시작일, 종료일 (yyyy-MM-dd)
  public static final String FILTER_FROM = "from";
  public static final String FILTER_TO = "to";

  // 기간 하한 — 서비스 개시(2026년) 이전이면 충분하다
  static final LocalDate EARLIEST_DATE = LocalDate.of(2000, 1, 1);

  private AdminListPeriod() {
  }

  /// 기간 보정: 비었거나 형식이 틀리면 기본 기간, 오늘 이후는 오늘, 2000-01-01 이전은 그날, 시작 > 종료면 서로 바꿈
  public static AdminListQuery withCorrectedPeriod(AdminListQuery query, LocalDate today) {
    LocalDate defaultFrom = today.minusDays(AdminListDefaults.DEFAULT_PERIOD_DAYS - 1L);
    LocalDate from = clamp(parseDate(query.filters().get(FILTER_FROM), defaultFrom), today);
    LocalDate to = clamp(parseDate(query.filters().get(FILTER_TO), today), today);
    if (from.isAfter(to)) {
      LocalDate swapped = from;
      from = to;
      to = swapped;
    }
    return query.withFilter(FILTER_FROM, from.toString()).withFilter(FILTER_TO, to.toString());
  }

  /// 기간 시작(포함): 보정된 쿼리 기준
  public static LocalDateTime periodStart(AdminListQuery query) {
    return LocalDate.parse(query.filters().get(FILTER_FROM)).atStartOfDay();
  }

  /// 기간 끝(미포함): 종료일 다음 날 0시
  public static LocalDateTime periodEndExclusive(AdminListQuery query) {
    return LocalDate.parse(query.filters().get(FILTER_TO)).plusDays(1).atStartOfDay();
  }

  private static LocalDate parseDate(String raw, LocalDate fallback) {
    LocalDate parsed = AdminDateParameter.parseOrNull(raw);
    return parsed == null ? fallback : parsed;
  }

  private static LocalDate clamp(LocalDate date, LocalDate today) {
    if (date.isAfter(today)) {
      return today;
    }
    return date.isBefore(EARLIEST_DATE) ? EARLIEST_DATE : date;
  }
}
