package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import java.time.LocalDateTime;

public record AdminRoutineResponse(
  String id,
  String title,
  String memberNickname,
  String memberUsername,
  RoutineStatus status,
  LocalDateTime scheduledAt,
  LocalDateTime completedAt
) {

  public static AdminRoutineResponse from(Routine routine) {
    return new AdminRoutineResponse(
      routine.getId(),
      routine.getTitle(),
      routine.getMember().getNickname(),
      routine.getMember().getUsername(),
      routine.getStatus(),
      routine.getScheduledAt(),
      routine.getCompletedAt()
    );
  }
}
