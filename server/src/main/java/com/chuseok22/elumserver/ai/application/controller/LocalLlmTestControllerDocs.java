package com.chuseok22.elumserver.ai.application.controller;

import com.chuseok22.elumserver.ai.application.dto.request.SensitiveInfoCheckRequest;
import com.chuseok22.elumserver.ai.application.dto.response.SensitiveInfoCheckResponse;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;

@Tag(
  name = "LocalLlmTest (임시)",
  description = "로컬 LLM 민감정보 사전 검토 기능 수동 검증용 임시 API. Routine 등 실제 도메인 연동 전까지만 유지합니다."
)
public interface LocalLlmTestControllerDocs {

  @Operation(
    summary = "텍스트 민감정보 검토 (수동 테스트)",
    description = """
      입력한 텍스트를 로컬 LLM(ai.suhsaechan.kr)에 보내 민감정보 포함 여부를 판정받습니다.

      **처리 로직**
      1. `local-llm.enabled=false`이면 로컬 LLM을 호출하지 않고 checked=false로 즉시 통과 처리합니다.
      2. 로컬 LLM 호출이 타임아웃되거나 실패하면 예외 없이 checked=false로 통과 처리합니다(fail-open 정책).
      3. 정상 응답을 받으면 checked=true와 함께 hasSensitiveInfo/categories/reason을 반환합니다.

      **주의**
      - 이 엔드포인트는 실제 도메인 기능(Routine 등)이 이 서비스를 직접 호출하기 전까지의 수동 검증용 임시 API입니다. Routine 등에서 `SensitiveInfoGuardService`를 직접 호출하게 되면 이 컨트롤러/DTO 4개 파일은 삭제합니다.
      - accessToken(Bearer) 인증이 필요합니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(
      responseCode = "200",
      description = "검토 완료 (통과 처리 포함)",
      content = @Content(schema = @Schema(implementation = SensitiveInfoCheckResponse.class))
    ),
    @ApiResponse(
      responseCode = "400",
      description = "text가 비어있는 경우",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"INVALID_INPUT_VALUE\",\"errorMessage\":\"text: text는 필수입니다.\"}"
        )
      )
    ),
    @ApiResponse(
      responseCode = "401",
      description = "accessToken이 없거나 유효하지 않은 경우",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"INVALID_TOKEN\",\"errorMessage\":\"유효하지 않은 토큰입니다.\"}"
        )
      )
    )
  })
  ResponseEntity<SensitiveInfoCheckResponse> check(SensitiveInfoCheckRequest request);
}
