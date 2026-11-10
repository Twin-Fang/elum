package com.chuseok22.elumserver.routine.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDate;
import java.util.List;

/**
 * 이룸이 한 주 요약 (#1074): 보낸 일과 완료 기록에서 센 사실만
 * 원문(rawInputText)·보상 문구·평가 문구는 싣지 않음 (서비스 원칙 2·5)
 */
@Schema(description = "주간 리포트. 기록이 없는 주면 sentRoutineCount = 0 이고 목록은 비어 있습니다.")
public record WeeklyReportResponse(
  @Schema(description = "주 시작 (월요일)", example = "2026-11-02")
  LocalDate weekStart,
  @Schema(description = "주 끝 (일요일, 포함)", example = "2026-11-08")
  LocalDate weekEnd,
  @Schema(description = "이번 주인가 (오늘이 든 주)")
  boolean isCurrentWeek,
  @Schema(description = "이 주에 보낸 일과 수 (승인 후 이룸이에게 간 일과)")
  int sentRoutineCount,
  @Schema(description = "끝까지 마친 일과 수")
  int completedRoutineCount,
  @Schema(description = "일과 완료율 0~100 (마친 일과 / 보낸 일과, 반올림). 보낸 일과가 없으면 0")
  int completionPercent,
  @Schema(description = "받은 별 (이 주 일과에서 마친 카드 수 — 별은 카드 1장당 1개)")
  int starsEarned,
  @Schema(description = "보상까지 간 일과 수 (보상을 정해 둔 일과 중 끝까지 마친 것). 보상 문구는 싣지 않는다")
  int rewardReachedCount,
  @Schema(description = "일과를 하나 이상 마친 날이 이어진 가장 긴 날 수 (이 주 안)")
  int longestCompletedDayStreak,
  @Schema(description = "월 ~ 일 7칸")
  List<Day> days,
  @Schema(description = "일과별 기록. 같은 원본에서 보낸 일과는 하나로 묶는다. 마친 횟수가 많은 순")
  List<RoutineSummary> routines,
  @Schema(description = "지난 날 일과에서 마치지 않은 채 남은 카드, 많이 남은 순 최대 3개. 오늘 일과는 아직 진행 중이라 세지 않는다")
  List<RemainingStep> remainingSteps,
  @Schema(description = "AI 정리 글. 끝난 주이고 마친 일과가 있을 때만 있고, 이번 주·기록 없는 주는 null", nullable = true)
  Summary summary,
  @Schema(description = "규칙으로 센 인사이트 (AI 아님). 기록이 전혀 없는 주는 null", nullable = true)
  WeeklyReportInsightsResponse insights
) {

  /// 집계 결과에 정리 글을 붙인 사본 (집계는 정리 글을 모름)
  public WeeklyReportResponse withSummary(Summary newSummary) {
    return new WeeklyReportResponse(weekStart, weekEnd, isCurrentWeek, sentRoutineCount, completedRoutineCount,
      completionPercent, starsEarned, rewardReachedCount, longestCompletedDayStreak, days, routines, remainingSteps,
      newSummary, insights);
  }

  /// 집계 결과에 인사이트를 붙인 사본 (집계는 인사이트를 모름)
  public WeeklyReportResponse withInsights(WeeklyReportInsightsResponse newInsights) {
    return new WeeklyReportResponse(weekStart, weekEnd, isCurrentWeek, sentRoutineCount, completedRoutineCount,
      completionPercent, starsEarned, rewardReachedCount, longestCompletedDayStreak, days, routines, remainingSteps,
      summary, newInsights);
  }

  /// 정리 글: 한 줄씩(최대 3줄, 이룸이 이름 이미 끼워 넣음) + 출처 (AI 가 쓴 글 / 서버가 집계로 만든 고정 문장)
  public record Summary(List<String> lines, SummarySource source) {

  }

  public enum SummarySource {
    AI,
    FALLBACK
  }

  /// 하루 칸: 보낸 일과 수 · 마친 일과 수
  public record Day(LocalDate date, int sentCount, int completedCount) {

  }

  /// 일과 하나 (원본 기준 묶음): 보낸 횟수 · 마친 횟수
  public record RoutineSummary(String title, int sentCount, int completedCount) {

  }

  /// 남은 카드 하나: 어느 일과의 어느 카드가 몇 번 남았나
  public record RemainingStep(String routineTitle, String stepTitle, int remainingCount) {

  }
}
