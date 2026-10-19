package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

@Schema(description = "일과관리 묶음 구성 바꾸기 요청 (#806). 넣기·빼기·순서 바꾸기를 한 번에")
public record RoutineGroupRoutinesUpdateRequest(

  @Schema(description = "묶음의 새 구성. 이 차례가 이룸이가 보는 순서. 빠진 일과는 묶음에서 나간다. "
    + "2개 미만이면 ROUTINE_GROUP_TOO_SMALL — 묶음을 풀려면 DELETE 를 부른다", example = "[\"routine-2\", \"routine-1\"]")
  List<String> routineIds
) {

}
