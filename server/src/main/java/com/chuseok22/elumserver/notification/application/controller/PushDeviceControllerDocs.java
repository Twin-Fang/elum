package com.chuseok22.elumserver.notification.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.notification.application.dto.request.PushDeviceRegisterRequest;
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
  name = "PushDevice",
  description = "보호자 기기의 푸시 토큰을 등록·해제하는 API. 보호자 accessToken(Bearer) 인증이 필요합니다. "
    + "이룸이 권한으로는 부를 수 없습니다."
)
public interface PushDeviceControllerDocs {

  @Operation(
    summary = "푸시 기기 등록",
    description = """
      푸시 토큰을 이 보호자의 기기로 등록합니다. 앱을 열 때마다 불러도 됩니다.

      - 같은 토큰이 이미 있으면 소유자·언어(Accept-Language)·등록 시각을 갱신합니다. 다른 보호자 것이었어도 이 보호자로 옮깁니다.
      - 토큰이 비었거나 공백뿐이거나 2048자를 넘거나 platform 이 없으면 400 `PUSH_TOKEN_INVALID`.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "204", description = "등록 성공"),
    @ApiResponse(responseCode = "400", description = "토큰 또는 platform 이 올바르지 않음(PUSH_TOKEN_INVALID)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "403", description = "이룸이 권한으로는 부를 수 없음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<Void> register(Authentication authentication, PushDeviceRegisterRequest request);

  @Operation(
    summary = "푸시 기기 해제",
    description = "로그아웃 때 이 기기의 푸시 토큰을 지웁니다. 내 토큰이 아니거나 없는 토큰이어도 아무 일 없이 204 입니다."
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "204", description = "처리 완료(지울 것이 없어도 204)"),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "403", description = "이룸이 권한으로는 부를 수 없음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<Void> unregister(Authentication authentication, String token);
}
