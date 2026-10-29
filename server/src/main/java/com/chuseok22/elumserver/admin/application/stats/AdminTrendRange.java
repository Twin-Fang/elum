package com.chuseok22.elumserver.admin.application.stats;

import com.chuseok22.elumserver.admin.application.list.AdminDateParameter;
import com.chuseok22.elumserver.common.application.stats.StatsBucketUnit;
import java.time.LocalDate;

/**
 * 추이 조회 범위: 화면 값(unit, from, to) > 보정된 단위·기간
 * 기본: 일별 최근 defaultDays 일, 월별 최근 12달 / 잘못된 날짜는 기본값, 순서가 뒤집히면 맞바꿈, 미래는 오늘까지
 */
public record AdminTrendRange(StatsBucketUnit unit, LocalDate from, LocalDate to) {

  /// 월별 기본 칸 수 (12달)
  static final int DEFAULT_MONTH_COUNT = 12;

  public static AdminTrendRange of(String unitParameter, String fromParameter, String toParameter,
    LocalDate today, int defaultDays) {
    StatsBucketUnit unit = StatsBucketUnit.fromParameter(unitParameter);
    LocalDate to = AdminDateParameter.parseOrNull(toParameter);
    if (to == null || to.isAfter(today)) {
      to = today;
    }
    LocalDate from = AdminDateParameter.parseOrNull(fromParameter);
    if (from == null) {
      from = unit == StatsBucketUnit.MONTH
        ? to.withDayOfMonth(1).minusMonths(DEFAULT_MONTH_COUNT - 1L)
        : to.minusDays(defaultDays - 1L);
    }
    if (from.isAfter(to)) {
      LocalDate later = from.isAfter(today) ? today : from;
      from = to;
      to = later;
    }
    return new AdminTrendRange(unit, from, to);
  }

  /** 캐시 키 조각 (unit|from|to) */
  public String cacheKey() {
    return unit.sqlName() + "|" + from + "|" + to;
  }
}
