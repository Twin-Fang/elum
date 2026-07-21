package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import java.time.LocalDateTime;

public record AdminRoutineStepResponse(
  String id,
  Integer stepOrder,
  String description,
  Boolean completed,
  LocalDateTime completedAt
) {

  public static AdminRoutineStepResponse from(RoutineStep step) {
    return new AdminRoutineStepResponse(
      step.getId(),
      step.getStepOrder(),
      step.getDescription(),
      step.getCompleted(),
      step.getCompletedAt()
    );
  }
}
