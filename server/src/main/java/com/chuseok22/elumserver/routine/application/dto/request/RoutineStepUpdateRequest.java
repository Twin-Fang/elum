package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;

@Schema(description = "일과 단계 설명 수정 요청")
public record RoutineStepUpdateRequest(

  @Schema(description = "수정할 단계 설명", example = "현관 우산꽂이에서 파란색 우산을 챙겨요.")
  @NotBlank(message = "description은 필수입니다.")
  String description
) {

}
