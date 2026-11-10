package com.chuseok22.elumserver.routine.application.dto.request;

import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleStatus;
import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "규칙 고치기: status(ACTIVE | OFF) 또는 text(직접 적은 규칙만) 중 하나 이상")
public record RoutineMemoryRuleUpdateRequest(

  @Schema(description = "ACTIVE: 지금 적용(관찰 중 > 적용 포함) / OFF: 끔. WATCHING 으로는 못 바꾼다", nullable = true)
  RoutineMemoryRuleStatus status,

  @Schema(description = "새 글 (직접 적은 규칙만)", nullable = true)
  String text
) {

}
