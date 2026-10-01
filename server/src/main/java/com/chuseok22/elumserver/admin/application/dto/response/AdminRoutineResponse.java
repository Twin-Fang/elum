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

  /** 보호자 칸은 일과를 만든 사람의 계정 이름이다 (옛 대표 보호자 컬럼은 V32 에서 지웠다). */
  public static AdminRoutineResponse from(Routine routine, String creatorUsername) {
    return new AdminRoutineResponse(
      routine.getId(),
      routine.getTitle(),
      routine.getProfile().getNickname(),
      creatorUsername,
      routine.getStatus(),
      routine.getScheduledAt(),
      routine.getCompletedAt()
    );
  }
}
