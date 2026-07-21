package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import java.time.LocalDateTime;
import java.util.List;

public record AdminRoutineDetailResponse(
  String id,
  String title,
  String memberNickname,
  String memberUsername,
  RoutineStatus status,
  String rawInputText,
  String sanitizedInputText,
  String revisionFeedback,
  LocalDateTime scheduledAt,
  LocalDateTime completedAt,
  List<AdminRoutineStepResponse> steps
) {

  public static AdminRoutineDetailResponse from(Routine routine) {
    List<AdminRoutineStepResponse> stepResponses = routine.getSteps().stream()
      .map(AdminRoutineStepResponse::from)
      .toList();
    return new AdminRoutineDetailResponse(
      routine.getId(),
      routine.getTitle(),
      routine.getMember().getNickname(),
      routine.getMember().getUsername(),
      routine.getStatus(),
      routine.getRawInputText(),
      routine.getSanitizedInputText(),
      routine.getRevisionFeedback(),
      routine.getScheduledAt(),
      routine.getCompletedAt(),
      stepResponses
    );
  }
}
