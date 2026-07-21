package com.chuseok22.elumserver.routine.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "추천 일과 응답")
public record RoutineSuggestionResponse(

  @Schema(description = "아이콘(유니코드 이모지)", example = "☂️")
  String icon,

  @Schema(description = "추천 일과 문구", example = "비 오는 날 등교 준비")
  String text
) {

}
