package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

@Schema(description = "일과관리 묶음 만들기 요청 (#806)")
public record RoutineGroupCreateRequest(

  @Schema(description = "묶음 이름. 앞뒤 공백을 지운 뒤 1~12자, 아니면 INVALID_INPUT_VALUE", example = "아침 묶음")
  String name,

  @Schema(description = "묶음에 넣을 원본 일과 ID. 이 차례가 이룸이가 보는 순서. 2개 이상, 아니면 ROUTINE_GROUP_TOO_SMALL",
    example = "[\"routine-1\", \"routine-2\"]")
  List<String> routineIds
) {

}
