package com.chuseok22.elumserver.feedback.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.feedback.application.dto.request.FeedbackRequest;
import com.chuseok22.elumserver.feedback.application.dto.response.FeedbackResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;

@Tag(
  name = "Feedback",
  description = "보호자가 앱에서 의견을 보내는 API. 보호자 accessToken(Bearer) 인증이 필요합니다. "
    + "이룸이 권한으로는 부를 수 없습니다."
)
public interface FeedbackControllerDocs {

  @Operation(
    summary = "의견 보내기",
    description = """
      의견 글과(선택) 앱 상태 기록을 저장합니다. 관리자 화면에서 볼 수 있습니다.

      **검사**
      1. 글이 비었거나 공백뿐이면 400 `FEEDBACK_MESSAGE_EMPTY`.
      2. 글이 2000자를 넘으면 400 `FEEDBACK_MESSAGE_TOO_LONG`.
      3. 앱 상태 기록이 256KB(UTF-8)를 넘으면 400 `FEEDBACK_LOG_TOO_LARGE`.
      4. 오늘(서버 시각 0시 시작) 이미 20건을 보냈으면 429 `FEEDBACK_RATE_LIMITED`.

      `appVersion`(32자)·`os`(64자)는 넘으면 거절하지 않고 잘라서 저장합니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "저장 성공",
      content = @Content(schema = @Schema(implementation = FeedbackResponse.class))),
    @ApiResponse(responseCode = "400",
      description = "글 없음(FEEDBACK_MESSAGE_EMPTY) · 글 초과(FEEDBACK_MESSAGE_TOO_LONG) · 기록 초과(FEEDBACK_LOG_TOO_LARGE)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "429", description = "오늘 보낼 수 있는 횟수 초과(FEEDBACK_RATE_LIMITED)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<FeedbackResponse> submit(Authentication authentication, FeedbackRequest request);
}
