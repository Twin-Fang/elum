package com.chuseok22.elumserver.routine.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;

/**
 * 주간 리포트 인사이트: 칭찬 거리, 막힌 카드, 지난주 대비, 걸린 시간, 가장 오래 걸린 카드
 * 규칙으로 센 값 (AI 아님). 칸마다 조건이 안 되면 null, 기록 없는 주는 인사이트 자체가 null
 */
@Schema(description = "주간 인사이트. 칸마다 조건이 안 되면 null")
public record WeeklyReportInsightsResponse(
  @Schema(description = "이번 주 칭찬 거리", nullable = true)
  Highlight highlight,
  @Schema(description = "자주 남은 카드", nullable = true)
  Stuck stuck,
  @Schema(description = "지난주와 끝낸 일과 수 비교", nullable = true)
  Trend trend,
  @Schema(description = "같은 일과가 걸린 시간 변화", nullable = true)
  Duration duration,
  @Schema(description = "가장 오래 걸린 카드", nullable = true)
  SlowestStep slowestStep
) {

  public enum HighlightKind {
    /// 같은 원본 일과를 이 주에 처음 끝까지 함
    FIRST_TIME_COMPLETED,
    /// 이 주에 3번 이상 보냈고 전부 끝냄
    EVERY_TIME_COMPLETED,
    /// 끝낸 날이 3일 이상 이어짐
    LONGEST_STREAK
  }

  public enum StuckSuggestion {
    /// 카드를 줄이거나 나누기
    SHORTEN_OR_SPLIT,
    /// 보호자 목소리나 사진 더하기
    ADD_VOICE_OR_PHOTO
  }

  /// routineTitle: 연속 기록(LONGEST_STREAK)이면 null. streakDays: 그 밖의 종류는 0
  public record Highlight(HighlightKind kind, String routineTitle, int completedCount, int sentCount, int streakDays) {

  }

  /// libraryRoutineId: 보낸 사본의 원본 일과. 원본이 없거나 지워졌으면 null
  public record Stuck(String libraryRoutineId, String routineTitle, String stepTitle, int stepOrder,
                      int remainedCount, int sentCount, StuckSuggestion suggestion) {

  }

  public record Trend(int previousCompletedRoutineCount, int currentCompletedRoutineCount) {

  }

  public record Duration(String routineTitle, int previousAverageMinutes, int currentAverageMinutes) {

  }

  public record SlowestStep(String routineTitle, String stepTitle, int averageMinutes) {

  }
}
