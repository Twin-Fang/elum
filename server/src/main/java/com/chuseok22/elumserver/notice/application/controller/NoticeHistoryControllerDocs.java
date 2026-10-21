package com.chuseok22.elumserver.notice.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.notice.application.dto.response.NoticeHistoryPageResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;

@Tag(
  name = "Notice History",
  description = "알림 화면의 공지 탭 API. 보호자 accessToken(Bearer) 인증이 필요합니다. 이룸이 권한으로는 부를 수 없습니다."
)
public interface NoticeHistoryControllerDocs {

  @Operation(
    summary = "공지 탭 목록",
    description = """
      최근 90일 안에 올라온 공지를 최신순으로 줍니다. **게시가 끝난 공지도 포함**합니다.

      - 켜져 있고, 시작 시각이 지났고, 요청 언어(Accept-Language)와 같고, 이 플랫폼에 닿는 공지만 줍니다.
      - 올라온 시각은 시작 시각 또는 "다시 보이게"로 고친 시각 중 늦은 쪽입니다.
      - `size` 기본 20, 최대 50. `nextCursor` 를 다음 요청의 `cursor` 로 넘기면 이어서 줍니다. 마지막 쪽이면 null.
      - 모르는 `platform` 값은 400 `NOTICE_PLATFORM_INVALID`.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "조회 완료"),
    @ApiResponse(responseCode = "400", description = "모르는 플랫폼 값 (`NOTICE_PLATFORM_INVALID`)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "403", description = "이룸이 권한으로는 부를 수 없음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<NoticeHistoryPageResponse> history(
    @Parameter(description = "IOS 또는 ANDROID. 비우면 전체 대상 공지만 준다", example = "IOS") String platform,
    @Parameter(description = "이전 쪽의 nextCursor") String cursor,
    @Parameter(description = "한 쪽 개수. 기본 20, 최대 50", example = "20") Integer size
  );

  @Operation(
    summary = "공지 탭 읽음 기록",
    description = "공지 탭을 열었을 때 부릅니다. 읽은 시각을 지금으로 기록(없으면 만들고 있으면 갱신)해 안 읽은 공지 표시를 지웁니다."
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "204", description = "기록 완료"),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "403", description = "이룸이 권한으로는 부를 수 없음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<Void> markSeen(Authentication authentication);
}
