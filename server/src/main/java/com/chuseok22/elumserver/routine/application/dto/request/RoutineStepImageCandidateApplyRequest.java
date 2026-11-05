package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;

/**
 * 새 그림 후보 고르기: 다시 그리기 응답의 candidateImagePath 를 그대로 (다른 후보로 바뀌었으면 404)
 */
@Schema(description = "새 그림으로 바꾸기 요청")
public record RoutineStepImageCandidateApplyRequest(

  @Schema(description = "다시 그리기 응답의 candidateImagePath", example = "step-1/ai-0f8fad5b-d9cb-469f-a165-70867728950e.png",
    requiredMode = Schema.RequiredMode.REQUIRED)
  String candidateImagePath
) {

}
