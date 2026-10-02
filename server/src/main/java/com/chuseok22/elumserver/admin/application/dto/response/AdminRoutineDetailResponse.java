package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.common.locale.AppLocale;
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
  List<AdminRoutineStepResponse> steps,
  /** 일과의 콘텐츠 언어 코드. */
  String language
) {

  public static AdminRoutineDetailResponse from(Routine routine, String creatorUsername) {
    List<AdminRoutineStepResponse> stepResponses = routine.getSteps().stream()
      .map(AdminRoutineStepResponse::from)
      .toList();
    return new AdminRoutineDetailResponse(
      routine.getId(),
      routine.getTitle(),
      routine.getProfile().getNickname(),
      creatorUsername,
      routine.getStatus(),
      routine.getRawInputText(),
      routine.getSanitizedInputText(),
      routine.getRevisionFeedback(),
      routine.getScheduledAt(),
      routine.getCompletedAt(),
      stepResponses,
      // 마이그레이션 전 행은 null 일 수 있어 ko 로 떨어뜨린다
      routine.getLanguage() == null ? AppLocale.KO.code() : routine.getLanguage().code()
    );
  }
}
