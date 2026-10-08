package com.chuseok22.elumserver.feedback.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "의견 보내기 응답")
public record FeedbackResponse(
  @Schema(description = "저장된 의견 id")
  String id
) {
}
