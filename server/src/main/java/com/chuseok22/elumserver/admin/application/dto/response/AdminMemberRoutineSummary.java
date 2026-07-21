package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import java.time.LocalDateTime;

public record AdminMemberRoutineSummary(
  String id,
  String title,
  RoutineStatus status,
  LocalDateTime scheduledAt
) {

  public static AdminMemberRoutineSummary from(Routine routine) {
    return new AdminMemberRoutineSummary(
      routine.getId(),
      routine.getTitle(),
      routine.getStatus(),
      routine.getScheduledAt()
    );
  }
}
