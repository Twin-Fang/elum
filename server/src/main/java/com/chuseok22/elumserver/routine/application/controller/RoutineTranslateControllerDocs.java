package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.common.infrastructure.constant.IdempotencyHeader;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineTranslateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.enums.ParameterIn;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;

/**
 * 다른 언어로 만들기 API 문서 (#1077). Swagger 묶음은 RoutineControllerDocs 와 같음
 */
@Tag(name = RoutineControllerDocs.TAG_NAME, description = RoutineControllerDocs.TAG_DESCRIPTION)
public interface RoutineTranslateControllerDocs {

  @Operation(
    summary = "다른 언어로 만들기 (Pro)",
    description = """
      일과의 **글만** 다른 언어로 바꾼 **새 원본**을 일과관리에 만듭니다 (#1077). 원래 일과는 그대로입니다.

      - AI 텍스트 호출 1번. 보내는 글은 일과 제목·보상 이름·카드 제목·설명뿐이고 보호자가 처음 쓴 글은 보내지 않습니다.
        이룸이 이름은 자리표시로 바꿔 보내고 응답에서 되돌립니다.
      - 그림·픽토그램·사진은 그대로 씁니다(그림을 새로 만들지 않음). 크레딧은 글 단가(`ROUTINE_TEXT`)만 씁니다.
      - 새 일과: `language` = 요청 언어, 상태 `CONFIRMED`, `sourceRoutineId` null, **일과관리에만** 있음(홈에 안 뜸, `보내기`로 오늘 일과가 됨).
      - `Idempotency-Key` 헤더를 주면 같은 키로 다시 와도 AI 를 다시 부르지 않고 만든 일과를 돌려줍니다.
      - 요금제에 없음 403(`ROUTINE_TRANSLATE_NOT_ALLOWED`), 임시저장·카드 없음 409(`ROUTINE_INVALID_STATUS`),
        모르는 언어·앱이 열지 않은 언어·원래 언어와 같음 400(`INVALID_INPUT_VALUE`), 크레딧 부족 403(`AI_CREDIT_INSUFFICIENT`).
      - AI 응답이 비었거나 카드 수가 다르면 사본을 만들지 않고 502(`ROUTINE_TRANSLATE_FAILED`), 크레딧은 돌려줍니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(
      responseCode = "200",
      description = "새 언어의 일과를 만듦",
      content = @Content(schema = @Schema(implementation = RoutineResponse.class))
    ),
    @ApiResponse(
      responseCode = "403",
      description = "요금제에 없음 / 크레딧 부족",
      content = @Content(
        schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(
          value = "{\"errorCode\":\"ROUTINE_TRANSLATE_NOT_ALLOWED\",\"errorMessage\":\"다른 언어로 만들기는 Pro에서 쓸 수 있어요.\"}"
        )
      )
    ),
    @ApiResponse(
      responseCode = "502",
      description = "AI 번역 실패 (사본 없음, 크레딧 반환)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))
    )
  })
  ResponseEntity<RoutineResponse> translate(
    Authentication authentication, String routineId,
    @Parameter(in = ParameterIn.HEADER, name = IdempotencyHeader.NAME, description = "누를 때마다 새로 만든 키 (선택)")
    String idempotencyKey,
    RoutineTranslateRequest request
  );
}
