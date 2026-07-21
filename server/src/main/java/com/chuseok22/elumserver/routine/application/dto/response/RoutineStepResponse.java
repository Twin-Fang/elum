package com.chuseok22.elumserver.routine.application.dto.response;

import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDateTime;

@Schema(description = "일과 단계 응답")
public record RoutineStepResponse(

  @Schema(description = "단계 ID")
  String id,

  @Schema(description = "단계 순서", example = "1")
  Integer stepOrder,

  @Schema(description = "아동 눈높이 설명", example = "옷을 벗어요")
  String description,

  @Schema(description = "생성된 이미지 저장 경로")
  String imagePath,

  @Schema(description = "완료 여부", example = "false")
  Boolean completed,

  @Schema(description = "완료 시각(KST), 미완료 시 null")
  LocalDateTime completedAt
) {

  public static RoutineStepResponse from(RoutineStep step) {
    return new RoutineStepResponse(
      step.getId(),
      step.getStepOrder(),
      step.getDescription(),
      step.getImagePath(),
      step.getCompleted(),
      step.getCompletedAt()
    );
  }
}
