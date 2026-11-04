package com.chuseok22.elumserver.expertroutine.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "가져오기 결과: 일과관리에 새로 만든 일과")
public record ExpertRoutineImportResponse(
  @Schema(description = "새로 만든 일과 id")
  String routineId,
  @Schema(description = "일과가 들어간 이룸이 id")
  String profileId
) {

}
