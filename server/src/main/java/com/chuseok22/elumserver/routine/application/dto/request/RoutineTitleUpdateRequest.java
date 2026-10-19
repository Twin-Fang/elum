package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "일과 제목 수정 요청 (#804). 앞뒤 공백을 지운 뒤 1~30자")
public record RoutineTitleUpdateRequest(

  @Schema(description = "새 일과 제목. 공백만 있거나 30자를 넘으면 INVALID_INPUT_VALUE", example = "아침 등교 준비")
  String title
) {

}
