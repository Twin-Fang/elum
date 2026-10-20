package com.chuseok22.elumserver.talk.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.talk.application.dto.request.TalkBlockRequest;
import com.chuseok22.elumserver.talk.application.dto.request.TalkReportRequest;
import com.chuseok22.elumserver.talk.application.dto.response.TalkBlockResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.ArraySchema;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;

@Tag(
  name = "Talk Moderation",
  description = "이야기 신고·차단 API. 보호자 accessToken(Bearer) 인증이 필요하며 "
    + "이룸이 권한으로는 부를 수 없습니다. 프로필 헤더(X-Profile-Id)는 필요 없습니다."
)
public interface TalkModerationControllerDocs {

  @Operation(
    summary = "글·댓글 신고",
    description = """
      글 또는 댓글을 신고합니다. 신고만으로 글이 숨겨지지는 않으며 운영팀이 확인한 뒤 처리합니다.

      **요청**
      1. `targetType`: `POST`(글) · `COMMENT`(댓글)
      2. `targetId`: 글 id 또는 댓글 id
      3. `reason`: `PERSONAL_INFO` · `OFFENSIVE` · `ADVERTISING` · `OTHER`

      **오류**
      1. 값이 비었거나 모르는 값이면 400 `INVALID_INPUT_VALUE`.
      2. 없거나 내려간 글이면 404 `TALK_POST_NOT_FOUND`, 없거나 지운 댓글이면 404 `TALK_COMMENT_NOT_FOUND`.
      3. 같은 대상을 이미 신고했으면 409 `TALK_REPORT_DUPLICATED`.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "204", description = "신고 접수"),
    @ApiResponse(responseCode = "400", description = "값이 비었거나 모르는 값(INVALID_INPUT_VALUE)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "404",
      description = "없는 글(TALK_POST_NOT_FOUND) · 없는 댓글(TALK_COMMENT_NOT_FOUND)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "409", description = "이미 신고함(TALK_REPORT_DUPLICATED)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<Void> report(Authentication authentication, TalkReportRequest request);

  @Operation(
    summary = "보호자 차단",
    description = """
      글 또는 댓글의 글쓴이를 차단합니다. `postId` 와 `commentId` 중 정확히 하나만 보냅니다.
      이미 차단했으면 아무 일도 없이 204 입니다.
      차단하면 그 보호자의 글·댓글이 피드와 댓글 목록에서 빠지고, 그 보호자가 보낸 알림도 오지 않습니다.

      **오류**
      1. 둘 다 보내거나 둘 다 비면 400 `INVALID_INPUT_VALUE`.
      2. 자기 자신이면 400 `TALK_CANNOT_BLOCK_SELF`.
      3. 없는 글·댓글이면 404 `TALK_POST_NOT_FOUND` · `TALK_COMMENT_NOT_FOUND`.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "204", description = "차단 성공(이미 차단했어도 204)"),
    @ApiResponse(responseCode = "400",
      description = "대상 지정 오류(INVALID_INPUT_VALUE) · 자기 자신(TALK_CANNOT_BLOCK_SELF)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "404",
      description = "없는 글(TALK_POST_NOT_FOUND) · 없는 댓글(TALK_COMMENT_NOT_FOUND)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<Void> block(Authentication authentication, TalkBlockRequest request);

  @Operation(
    summary = "차단 해제",
    description = """
      차단 목록의 `blockId` 로 차단을 풉니다. 내 차단이 아니거나 없는 id 면 400 `INVALID_INPUT_VALUE`.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "204", description = "해제 성공"),
    @ApiResponse(responseCode = "400", description = "내 차단이 아니거나 없음(INVALID_INPUT_VALUE)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<Void> unblock(Authentication authentication, @Parameter(description = "차단 id") String blockId);

  @Operation(
    summary = "내 차단 목록",
    description = "내가 차단한 보호자를 최근 차단 순으로 돌려줍니다. 보호자 id 는 내려주지 않고 닉네임만 보여줍니다."
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "조회 성공",
      content = @Content(array = @ArraySchema(schema = @Schema(implementation = TalkBlockResponse.class)))),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<List<TalkBlockResponse>> getBlocks(Authentication authentication);
}
