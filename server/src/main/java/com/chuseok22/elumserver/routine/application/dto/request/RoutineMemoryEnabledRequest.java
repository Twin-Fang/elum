package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "AI 메모리 켜기/끄기")
public record RoutineMemoryEnabledRequest(

  @Schema(description = "true 면 일과 만들기에 규칙·확정 예시를 넣고 고친 카드에서 수정을 찾는다. false 면 둘 다 안 함 (규칙은 남음)", example = "true")
  Boolean enabled
) {

}
