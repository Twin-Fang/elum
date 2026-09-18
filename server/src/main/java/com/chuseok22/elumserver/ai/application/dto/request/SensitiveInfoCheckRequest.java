package com.chuseok22.elumserver.ai.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 민감정보 사전 검토 요청.
 *
 * <p>로컬 LLM을 부르는 입구다. 빈 텍스트를 검사할 이유가 없다 (이슈 #215).
 */
@Schema(description = "민감정보 사전 검토 요청")
public record SensitiveInfoCheckRequest(

  @Schema(description = "검증할 원문 텍스트", example = "홍길동 010-1234-5678로 연락주세요",
    requiredMode = Schema.RequiredMode.REQUIRED)
  @NotBlank(message = "검사할 내용을 입력해주세요.")
  @Size(max = 1000, message = "검사할 내용은 1000자를 넘을 수 없습니다.")
  String text
) {

}
