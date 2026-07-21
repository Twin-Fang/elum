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

  @Schema(description = "단계 목록")
  List<RoutineStepResponse> steps
) {

  public static RoutineResponse from(Routine routine) {
    List<RoutineStepResponse> stepResponses = routine.getSteps().stream()
      .map(RoutineStepResponse::from)
      .toList();
    return new RoutineResponse(
      routine.getId(),
      routine.getTitle(),
      routine.getRawInputText(),
      routine.getSanitizedInputText(),
      routine.getScheduledAt(),
      routine.getStatus().name(),
      routine.getRevisionFeedback(),
      routine.getCompletedAt(),
      stepResponses
    );
  }
}
