package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "다른 언어로 만들기 요청 (#1077)")
public record RoutineTranslateRequest(

  @Schema(description = "만들 언어 코드. 앱이 여는 언어 중 원래 일과 언어가 아닌 것 (지금은 ko, en). 그 밖은 INVALID_INPUT_VALUE",
    example = "en")
  String language
) {

}
