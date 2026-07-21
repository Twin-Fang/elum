package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;

@Schema(description = "일과 재생성 피드백 요청")
public record RoutineReviseRequest(

  @Schema(description = "부모의 수정 요청 피드백", example = "3단계를 더 쉽게 바꿔줘")
  @NotBlank(message = "feedback은 필수입니다.")
  String feedback
) {

}
