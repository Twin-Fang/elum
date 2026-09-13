package com.chuseok22.elumserver.routine.application.dto.response;

import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDateTime;
import java.util.List;

@Schema(description = "일과 응답")
public record RoutineResponse(

  @Schema(description = "일과 ID")
  String id,

  @Schema(description = "AI가 생성한 제목", example = "병원에 다녀와요")
  String title,

  @Schema(description = "일과 원문(마스킹 전)", example = "내일 오후 3시에 병원 가기")
  String rawInputText,

  @Schema(description = "민감정보를 카테고리 태그로 치환한 텍스트(Gemini에 실제 전달된 값). 자동화 테스트가 없는 프로젝트 특성상, 마스킹이 실제로 적용됐는지 API 응답만으로 수동 검증할 수 있도록 노출한다.", example = "<이름>이랑 내일 오후 3시에 병원 가기")
  String sanitizedInputText,

  @Schema(description = "일과 수행 날짜/시각")
  LocalDateTime scheduledAt,

  @Schema(description = "상태", example = "PENDING_REVIEW")
  String status,

  @Schema(description = "최신 피드백(없으면 null)")
  String revisionFeedback,

  @Schema(description = "모든 단계를 완료한 시각(KST), 미완료 시 null")
  LocalDateTime completedAt,

  @Schema(description = "완료한 단계 수", example = "1")
  Integer completedStepCount,

  @Schema(description = "전체 단계 수", example = "2")
  Integer totalStepCount,

  @Schema(description = "진행률(%), 단계가 없으면 0", example = "50")
  Integer progressPercent,

  @Schema(description = "보호자가 정한 보상(강화물). 설정하지 않았으면 null — 아동 화면에서 보상 UI를 띄우지 않는다", example = "젤리 먹기")
  String rewardText,

  @Schema(description = "보상 프리셋 키. 직접 입력이면 CUSTOM 또는 null", example = "SNACK")
  String rewardPresetKey,

  @Schema(description = "단계 목록")
  List<RoutineStepResponse> steps
) {

  public static RoutineResponse from(Routine routine) {
    List<RoutineStepResponse> stepResponses = routine.getSteps().stream()
      .map(RoutineStepResponse::from)
      .toList();
    int totalStepCount = stepResponses.size();
    int completedStepCount = (int) stepResponses.stream()
      .filter(RoutineStepResponse::completed)
      .count();
    int progressPercent = totalStepCount == 0 ? 0 : (completedStepCount * 100) / totalStepCount;
    return new RoutineResponse(
      routine.getId(),
      routine.getTitle(),
      routine.getRawInputText(),
      routine.getSanitizedInputText(),
      routine.getScheduledAt(),
      routine.getStatus().name(),
      routine.getRevisionFeedback(),
      routine.getCompletedAt(),
      completedStepCount,
      totalStepCount,
      progressPercent,
      routine.getRewardText(),
      routine.getRewardPresetKey(),
      stepResponses
    );
  }
}
