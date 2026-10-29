package com.chuseok22.elumserver.talk.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "일과관리로 가져온 결과")
public record TalkImportResponse(
  @Schema(description = "만들어진 일과관리 일과 id")
  String routineId,
  @Schema(description = "일과가 들어간 이룸이 id")
  String profileId
) {

}
