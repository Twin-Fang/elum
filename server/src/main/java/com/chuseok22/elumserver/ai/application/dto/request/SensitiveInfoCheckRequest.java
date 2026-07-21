package com.chuseok22.elumserver.ai.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;

@Schema(description = "민감정보 사전 검토 요청")
public record SensitiveInfoCheckRequest(

  @Schema(description = "검증할 원문 텍스트", example = "홍길동 010-1234-5678로 연락주세요")
  @NotBlank(message = "text는 필수입니다.")
  String text
) {

}
