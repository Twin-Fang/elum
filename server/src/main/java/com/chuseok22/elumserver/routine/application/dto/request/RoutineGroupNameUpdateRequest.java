package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "일과관리 묶음 이름 바꾸기 요청 (#806). 앞뒤 공백을 지운 뒤 1~12자")
public record RoutineGroupNameUpdateRequest(

  @Schema(description = "새 묶음 이름. 공백만 있거나 12자를 넘으면 INVALID_INPUT_VALUE", example = "저녁 묶음")
  String name
) {

}
