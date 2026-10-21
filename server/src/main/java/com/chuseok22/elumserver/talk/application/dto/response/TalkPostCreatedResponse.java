package com.chuseok22.elumserver.talk.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "이야기 올리기 결과")
public record TalkPostCreatedResponse(
  @Schema(description = "만들어진 글 id")
  String postId
) {

}
