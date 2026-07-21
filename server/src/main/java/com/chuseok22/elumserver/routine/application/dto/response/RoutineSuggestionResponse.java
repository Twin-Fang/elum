package com.chuseok22.elumserver.routine.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "추천 일과 응답")
public record RoutineSuggestionResponse(

  @Schema(description = "아이콘(유니코드 이모지)", example = "☂️")
  String icon,

  @Schema(description = "추천 일과 문구", example = "비 오는 날 등교 준비")
  String text,

  @Schema(description = "일과 생성 화면에 프리필할 수 있는 자연어 예시 문장", example = "지금 밖에 비가 오고 있는데 아이가 학교에 갈 준비를 해야 돼")
  String naturalLanguageExample
) {

}
