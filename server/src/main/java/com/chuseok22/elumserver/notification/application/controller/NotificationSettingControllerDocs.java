package com.chuseok22.elumserver.notification.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.notification.application.dto.request.NotificationSettingRequest;
import com.chuseok22.elumserver.notification.application.dto.response.NotificationSettingResponse;
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
  name = "NotificationSetting",
  description = "보호자의 푸시 알림 설정 API. 보호자 accessToken(Bearer) 인증이 필요합니다. "
    + "이룸이 권한으로는 부를 수 없습니다. 설정은 푸시 여부만 정하고 알림 목록에는 항상 쌓입니다."
)
public interface NotificationSettingControllerDocs {

  @Operation(
    summary = "알림 설정 조회",
    description = "저장된 설정이 없으면 여섯 값이 모두 true 입니다."
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "조회 성공",
      content = @Content(schema = @Schema(implementation = NotificationSettingResponse.class))),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "403", description = "이룸이 권한으로는 부를 수 없음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<NotificationSettingResponse> get(Authentication authentication);

  @Operation(
    summary = "알림 설정 저장",
    description = "여섯 값을 통째로 저장하고(없으면 만들고 있으면 덮어씀) 저장된 상태를 돌려줍니다."
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "저장 성공",
      content = @Content(schema = @Schema(implementation = NotificationSettingResponse.class))),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "403", description = "이룸이 권한으로는 부를 수 없음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<NotificationSettingResponse> update(Authentication authentication,
    NotificationSettingRequest request);
}
