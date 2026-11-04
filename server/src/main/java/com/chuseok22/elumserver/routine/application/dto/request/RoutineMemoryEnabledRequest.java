package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "AI 메모 켜기/끄기 (#1082)")
public record RoutineMemoryEnabledRequest(

  @Schema(description = "true 면 일과 만들기에 메모·확정 예시를 넣고 새 확정을 배운다. false 면 둘 다 안 함 (메모는 남음)", example = "true")
  Boolean enabled
) {

}
