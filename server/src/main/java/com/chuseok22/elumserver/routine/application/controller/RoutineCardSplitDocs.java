package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.routine.application.dto.request.CardSplitRequest;
import com.chuseok22.elumserver.routine.application.dto.response.CardSplitSuggestionResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;

/**
 * 이 카드 더 쉽게 API 문서 (Pro): 나눈 안 받기, 고른 안 적용
 * RoutineControllerDocs 가 묶어서 RoutineController 에 제공
 */
public interface RoutineCardSplitDocs {

  @Operation(
    summary = "카드 나누기 안 받기 (Pro)",
    description = """
      카드 한 장을 AI 가 더 작은 행동 2~3장으로 나눈 **안**을 돌려줍니다. 아무것도 저장하지 않습니다.

      - `SUGGESTED`: `cards` 2~3장
      - `ALREADY_SHORT`: `cards` 빈 목록. 이미 행동 하나뿐이라 나눌 것이 없음 (아주 짧은 카드는 AI 를 부르지 않고 바로 이 값)

      요금제 권한 `cardSplit` 이 꺼진 회원은 403 `CARD_SPLIT_PRO_REQUIRED`. 크레딧은 받지 않고, 하루 AI 비용 상한(503
      `AI_DAILY_BUDGET_EXCEEDED`)을 따릅니다.
      AI 실패·시간 초과·안이 규칙에 어긋나면 502 `CARD_SPLIT_FAILED`.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "안 받기 성공",
      content = @Content(schema = @Schema(implementation = CardSplitSuggestionResponse.class))),
    @ApiResponse(responseCode = "403", description = "Pro 아님 (CARD_SPLIT_PRO_REQUIRED) 또는 남의 일과",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(value = "{\"errorCode\":\"CARD_SPLIT_PRO_REQUIRED\",\"errorMessage\":\"Pro에서 쓸 수 있어요.\"}"))),
    @ApiResponse(responseCode = "404", description = "없는 일과 또는 카드",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "409", description = "이미 완료한 카드 (ROUTINE_STEP_ALREADY_COMPLETED)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "502", description = "AI 실패·시간 초과·안 검증 어긋남",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class),
        examples = @ExampleObject(value = "{\"errorCode\":\"CARD_SPLIT_FAILED\",\"errorMessage\":\"카드를 나누지 못했어요. 잠시 뒤 다시 해 주세요.\"}"))),
    @ApiResponse(responseCode = "503", description = "서비스 하루 AI 비용 상한 (AI_DAILY_BUDGET_EXCEEDED)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<CardSplitSuggestionResponse> suggestCardSplit(
    Authentication authentication, String routineId, String stepId
  );

  @Operation(
    summary = "카드 나누기 적용 (Pro)",
    description = """
      고른 안(2~3장)을 원래 카드 자리에 순서대로 넣고 원래 카드는 없앱니다. 한 트랜잭션입니다.

      새 카드의 그림은 카드를 직접 더할 때와 같은 기본 그림(무료 픽토그램)입니다. AI 그림을 만들지 않고 크레딧도 쓰지 않습니다.
      글 검증은 카드 더하기·고치기와 같습니다(제목 비울 수 없음·100자, 설명 300자). 장수가 2~3이 아니면 400.
      카드가 10장을 넘게 되면 409 `ROUTINE_STEP_MAX_COUNT`. 이미 완료한 카드는 409 `ROUTINE_STEP_ALREADY_COMPLETED`.
      응답은 `GET /api/routines/{routineId}` 와 같습니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "적용 성공",
      content = @Content(schema = @Schema(implementation = RoutineResponse.class))),
    @ApiResponse(responseCode = "400", description = "카드 장수가 2~3이 아님 · 제목이 비었음 · 글 길이 초과 (INVALID_INPUT_VALUE)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "403", description = "Pro 아님 (CARD_SPLIT_PRO_REQUIRED) 또는 남의 일과",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "404", description = "없는 일과 또는 카드",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "409", description = "카드가 10장을 넘게 됨 · 이미 완료한 카드",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<RoutineResponse> applyCardSplit(
    Authentication authentication, String routineId, String stepId, CardSplitRequest request
  );
}
