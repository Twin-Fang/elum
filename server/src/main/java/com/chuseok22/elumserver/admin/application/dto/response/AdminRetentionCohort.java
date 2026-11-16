package com.chuseok22.elumserver.admin.application.dto.response;

import java.time.LocalDate;
import java.util.List;

/**
 * 가입 주차 리텐션 한 행 (#1436): 가입 주, 인원, 1·2·4주 뒤 칸
 * 칸 문구 3가지: 비율 "33% (1명)", 아직 안 지난 주 "-", 방문 기록 시작 전 주 "기록 전"
 */
public record AdminRetentionCohort(String weekLabel, long cohortSize, List<Cell> cells) {

  /// 칸 문구: 아직 안 지남, 방문 기록 시작 전
  public static final String NOT_ELAPSED_TEXT = "-";
  public static final String BEFORE_TRACKING_TEXT = "기록 전";
  private static final int DAYS_PER_WEEK = 7;

  /** 칸 하나: 화면 문구와 비율(막대·색용, 숫자 칸이 아니면 null) */
  public record Cell(String text, Integer percent) {

    /** 가입 주 첫날 + weeksLater 주 > 칸 (안 끝난 주 "-", 방문 기록 시작 전·기록 없음 "기록 전") */
    public static Cell of(
      LocalDate cohortWeekStart, int weeksLater, long returnedCount, long cohortSize, LocalDate today,
      LocalDate trackingStartDate
    ) {
      LocalDate targetWeekStart = cohortWeekStart.plusDays((long) weeksLater * DAYS_PER_WEEK);
      LocalDate targetWeekEndExclusive = targetWeekStart.plusDays(DAYS_PER_WEEK);
      if (targetWeekEndExclusive.isAfter(today)) {
        return new Cell(NOT_ELAPSED_TEXT, null);
      }
      if (trackingStartDate == null || targetWeekStart.isBefore(trackingStartDate)) {
        return new Cell(BEFORE_TRACKING_TEXT, null);
      }
      int percent = cohortSize == 0 ? 0 : (int) Math.round(returnedCount * 100.0 / cohortSize);
      return new Cell(percent + "% (" + returnedCount + "명)", percent);
    }
  }
}
