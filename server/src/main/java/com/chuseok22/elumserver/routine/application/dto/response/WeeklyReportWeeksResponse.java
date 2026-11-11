package com.chuseok22.elumserver.routine.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDate;
import java.util.List;

/**
 * 주간 리포트를 볼 수 있는 주 목록: 마친 일과가 있는 주 (최신순, 최대 26개) + Free 첫 주 미리 보기 주
 */
@Schema(description = "마친 일과가 있는 주 목록. 이번 주도 마친 일과가 있으면 들어갑니다.")
public record WeeklyReportWeeksResponse(
  @Schema(description = "마친 일과가 있는 주, 최신순 최대 26개")
  List<Week> weeks,
  @Schema(
    description = "Free 가 볼 수 있는 한 주(마친 일과가 있는 가장 이른 주의 월요일). 미리 보기가 꺼져 있거나 "
      + "이미 주간 리포트 권한이 있거나 마친 일과가 없으면 null",
    example = "2026-10-26", nullable = true)
  LocalDate freePreviewWeekStart
) {

  /// 주 하나: 월요일 · 그 주에 마친 일과 수
  public record Week(
    @Schema(description = "주 시작 (월요일)", example = "2026-11-02")
    LocalDate weekStart,
    @Schema(description = "그 주에 마친 일과 수")
    int completedRoutineCount
  ) {

  }
}
