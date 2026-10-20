package com.chuseok22.elumserver.common.application.stats;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * 추이 그래프 묶음 단위 2개: 일별, 월별
 * sqlName: Postgres date_trunc 인자 / 범위 상한: 일별 366칸, 월별 36칸
 */
public enum StatsBucketUnit {

  DAY("day", 366, DateTimeFormatter.ofPattern("M/d")),
  MONTH("month", 36, DateTimeFormatter.ofPattern("yy.M")),
  ;

  private final String sqlName;
  private final int maximumBucketCount;
  private final DateTimeFormatter labelFormatter;

  StatsBucketUnit(String sqlName, int maximumBucketCount, DateTimeFormatter labelFormatter) {
    this.sqlName = sqlName;
    this.maximumBucketCount = maximumBucketCount;
    this.labelFormatter = labelFormatter;
  }

  public String sqlName() {
    return sqlName;
  }

  /** 화면 값(day, month) > 단위 (모르는 값은 일별) */
  public static StatsBucketUnit fromParameter(String value) {
    if (value != null && value.trim().toLowerCase(Locale.ROOT).equals(MONTH.sqlName)) {
      return MONTH;
    }
    return DAY;
  }

  /** 날짜 > 그 날짜가 속한 칸의 첫날 */
  public LocalDate bucketStartOf(LocalDate date) {
    return this == MONTH ? date.withDayOfMonth(1) : date;
  }

  /** 칸 첫날 > 다음 칸 첫날 */
  public LocalDate nextBucketStart(LocalDate bucketStart) {
    return this == MONTH ? bucketStart.plusMonths(1) : bucketStart.plusDays(1);
  }

  /** 칸 첫날 > 그래프 x축 이름 (10/20, 26.10) */
  public String labelOf(LocalDate bucketStart) {
    return labelFormatter.format(bucketStart);
  }

  /** 기간[from, to] > 칸 첫날 목록 (상한 넘으면 뒤쪽 최근 칸만) */
  public List<LocalDate> bucketStartsBetween(LocalDate from, LocalDate to) {
    LocalDate first = bucketStartOf(from);
    LocalDate last = bucketStartOf(to);
    long span = this == MONTH ? ChronoUnit.MONTHS.between(first, last) : ChronoUnit.DAYS.between(first, last);
    if (span + 1 > maximumBucketCount) {
      first = this == MONTH ? last.minusMonths(maximumBucketCount - 1L) : last.minusDays(maximumBucketCount - 1L);
    }
    List<LocalDate> starts = new ArrayList<>();
    for (LocalDate cursor = first; !cursor.isAfter(last); cursor = nextBucketStart(cursor)) {
      starts.add(cursor);
    }
    return starts;
  }
}
