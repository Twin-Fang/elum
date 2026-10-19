package com.chuseok22.elumserver.notification.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.notification.application.dto.response.NotificationPageResponse;
import com.chuseok22.elumserver.notification.application.dto.response.UnreadSummaryResponse;
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
  name = "Notification",
  description = "보호자 알림 목록·안 읽음 요약·읽음 처리 API. 보호자 accessToken(Bearer) 인증이 필요합니다. "
    + "이룸이 권한으로는 부를 수 없습니다."
)
public interface NotificationControllerDocs {

  @Operation(
    summary = "알림 목록",
    description = """
      내 알림을 최신순(마지막 발생 시각, id 내림차순)으로 한 쪽씩 줍니다.

      - cursor: 앞 쪽 응답의 nextCursor 를 그대로 보냅니다. 형식은 `{마지막 발생 시각}|{id}` 이고 `|` 가 들어 있으니 URL 인코딩해서 보냅니다. 비었거나 형식이 틀리면 첫 쪽입니다.
      - size: 기본 20, 최대 50. nextCursor 가 null 이면 마지막 쪽입니다.
      - profileName 은 지금도 접근할 수 있는 이룸이일 때만, routineTitle 은 지워지지 않았고 지금도 내가 돌보는 이룸이의 일과일 때만 채워집니다(아니면 null).
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "알림 목록 한 쪽"),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "403", description = "이룸이 권한으로는 부를 수 없음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<NotificationPageResponse> list(Authentication authentication, String cursor, Integer size);

  @Operation(
    summary = "안 읽음 요약",
    description = """
      하단 바 배지용 안 읽음 요약입니다.

      - hasUnreadNotification·unreadNotificationCount: 내 안 읽은 알림.
      - hasUnreadNotice: 공지 탭을 마지막으로 본 뒤 올라온 공지가 있는가. platform(IOS, ANDROID)을 보냅니다.
        platform 이 없거나 틀리면 공지는 확인하지 않고 hasUnreadNotice 만 false 입니다(요약은 실패하지 않음).
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "안 읽음 요약"),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "403", description = "이룸이 권한으로는 부를 수 없음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<UnreadSummaryResponse> unreadSummary(Authentication authentication, String platform);

  @Operation(
    summary = "알림 읽음",
    description = "알림 한 건을 읽음 처리합니다. 이미 읽은 알림이면 그대로 204 입니다. 없거나 남의 알림이면 404 `NOTIFICATION_NOT_FOUND` 입니다."
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "204", description = "읽음 처리 완료"),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "403", description = "이룸이 권한으로는 부를 수 없음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "404", description = "알림이 없거나 내 알림이 아님(NOTIFICATION_NOT_FOUND)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<Void> markRead(Authentication authentication, String id);

  @Operation(
    summary = "알림 전체 읽음",
    description = "내 안 읽은 알림을 모두 읽음 처리합니다. 안 읽은 알림이 없어도 204 입니다."
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "204", description = "읽음 처리 완료"),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "403", description = "이룸이 권한으로는 부를 수 없음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<Void> markAllRead(Authentication authentication);
}
