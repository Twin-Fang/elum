package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "직접 적는 AI 메모리 규칙")
public record RoutineMemoryRuleCreateRequest(

  @Schema(description = "규칙 글 (60자 안). 진단·장애·정도·연락처가 들면 400", example = "카드 글은 10자 안으로")
  String text
) {

}
