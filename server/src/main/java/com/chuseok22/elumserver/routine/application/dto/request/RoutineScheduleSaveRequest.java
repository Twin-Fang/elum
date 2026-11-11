package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

@Schema(description = "일과 반복 요일·시각 저장 요청 (#782, #1080). 같은 일과에 다시 보내면 덮어쓴다")
public record RoutineScheduleSaveRequest(

  @Schema(description = "반복할 요일 (1개 이상). MONDAY ~ SUNDAY", example = "[\"MONDAY\", \"WEDNESDAY\", \"FRIDAY\"]")
  List<String> weekdays,

  @Schema(description = "그 요일의 시각 (한국 시각, HH:mm 24시간)", example = "08:00")
  String time,

  @Schema(description = "그 시각에 이룸이 기기에 알림을 보낼지. 비우면 true", example = "true", nullable = true)
  Boolean notifyEnabled
) {

}
