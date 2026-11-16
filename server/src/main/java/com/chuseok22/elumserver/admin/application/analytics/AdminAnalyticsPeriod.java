package com.chuseok22.elumserver.admin.application.analytics;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.List;

/**
 * 사용 분석 기간 (#1436): 최근 4·8·12주(기본 8, 그 밖 값은 기본) + 모두 포함 여부
 * 주는 월요일 시작 (Postgres date_trunc('week') 와 같음). 범위 [첫 주 월요일 0시, 내일 0시)
 */
public record AdminAnalyticsPeriod(int weeks, boolean isIncludingAllAccounts, LocalDate firstWeekStart, LocalDate today) {

  /// 고를 수 있는 주 수 3개와 기본값
  public static final List<Integer> ALLOWED_WEEKS = List.of(4, 8, 12);
  public static final int DEFAULT_WEEKS = 8;
  private static final int DAYS_PER_WEEK = 7;
  /// 화면·주별 추이 JSON 주소 (기간·모두 포함을 붙여 씀)
  private static final String ANALYTICS_PATH = "/admin/analytics";
  private static final String WEEKLY_USAGE_PATH = "/admin/analytics/api/weekly-usage";

  /** 화면 값(weeks, includeAll) > 기간 (includeAll 은 "true" 일 때만 켬) */
  public static AdminAnalyticsPeriod of(String weeksParameter, String includeAllParameter, LocalDate today) {
    int weeks = parseAllowedWeeks(weeksParameter);
    boolean isIncludingAllAccounts = "true".equalsIgnoreCase(includeAllParameter);
    LocalDate firstWeekStart = weekStartOf(today).minusWeeks(weeks - 1L);
    return new AdminAnalyticsPeriod(weeks, isIncludingAllAccounts, firstWeekStart, today);
  }

  /** 날짜 > 그 주 월요일 */
  public static LocalDate weekStartOf(LocalDate date) {
    return date.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
  }

  public LocalDateTime from() {
    return firstWeekStart.atStartOfDay();
  }

  public LocalDateTime toExclusive() {
    return today.plusDays(1).atStartOfDay();
  }

  /** 주 첫날 목록 (오래된 주 먼저, 이번 주 포함) */
  public List<LocalDate> weekStarts() {
    List<LocalDate> starts = new ArrayList<>(weeks);
    for (int index = 0; index < weeks; index++) {
      starts.add(firstWeekStart.plusDays((long) index * DAYS_PER_WEEK));
    }
    return starts;
  }

  /** 기간 선택지 (4·8·12주) */
  public List<Integer> allowedWeekOptions() {
    return ALLOWED_WEEKS;
  }

  /** 그 주 수로 본 화면 주소 (모두 포함은 그대로) */
  public String analyticsPathFor(int weeksToShow) {
    return pathOf(ANALYTICS_PATH, weeksToShow, isIncludingAllAccounts);
  }

  /** 모두 포함을 켜고 끈 화면 주소 (기간은 그대로) */
  public String includeAllTogglePath() {
    return pathOf(ANALYTICS_PATH, weeks, !isIncludingAllAccounts);
  }

  /** 주별 추이 JSON 주소 (같은 기간·모두 포함) */
  public String weeklyUsageEndpoint() {
    return pathOf(WEEKLY_USAGE_PATH, weeks, isIncludingAllAccounts);
  }

  /** 캐시 키 조각 (주 수|모두 포함|오늘) */
  public String cacheKey() {
    return weeks + "|" + isIncludingAllAccounts + "|" + today;
  }

  // 주소?weeks=N(&includeAll=true)
  private static String pathOf(String path, int weeksToShow, boolean isIncludingAll) {
    return path + "?weeks=" + weeksToShow + (isIncludingAll ? "&includeAll=true" : "");
  }

  private static int parseAllowedWeeks(String weeksParameter) {
    try {
      int weeks = Integer.parseInt(weeksParameter == null ? "" : weeksParameter.trim());
      return ALLOWED_WEEKS.contains(weeks) ? weeks : DEFAULT_WEEKS;
    } catch (NumberFormatException e) {
      return DEFAULT_WEEKS;
    }
  }
}
