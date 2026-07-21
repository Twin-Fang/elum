package com.chuseok22.elumserver.ai.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "민감정보 사전 검토 요청")
public record SensitiveInfoCheckRequest(

  @Schema(description = "검증할 원문 텍스트", example = "홍길동 010-1234-5678로 연락주세요")
  String text
) {

}
