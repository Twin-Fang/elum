package com.chuseok22.elumserver.talk.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.talk.application.dto.request.TalkCommentRequest;
import com.chuseok22.elumserver.talk.application.dto.response.TalkCommentPageResponse;
import com.chuseok22.elumserver.talk.application.dto.response.TalkCommentResponse;
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
  name = "Talk Reaction",
  description = "이야기 반응 API: 도움이 됐어요, 댓글. 보호자 accessToken(Bearer) 인증이 필요하며 "
    + "이룸이 권한으로는 부를 수 없습니다. 프로필 헤더(X-Profile-Id)는 필요 없습니다."
)
public interface TalkReactionControllerDocs {

  @Operation(
    summary = "도움이 됐어요 누르기",
    description = """
      글에 도움이 됐어요를 누릅니다. 이미 눌렀으면 아무 일도 없이 204 입니다.
      내려간 글이면 404 `TALK_POST_NOT_FOUND`.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "204", description = "누르기 성공(이미 눌렀어도 204)"),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "404", description = "없거나 내려간 글(TALK_POST_NOT_FOUND)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<Void> markHelpful(Authentication authentication, @Parameter(description = "글 id") String postId);

  @Operation(
    summary = "도움이 됐어요 취소",
    description = """
      누른 도움이 됐어요를 취소합니다. 누른 적이 없으면 아무 일도 없이 204 입니다.
      내려간 글이면 404 `TALK_POST_NOT_FOUND`.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "204", description = "취소 성공(누른 적 없어도 204)"),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "404", description = "없거나 내려간 글(TALK_POST_NOT_FOUND)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<Void> unmarkHelpful(Authentication authentication, @Parameter(description = "글 id") String postId);

  @Operation(
    summary = "댓글 목록",
    description = """
      글의 댓글을 오래된 순으로 한 쪽 돌려줍니다.

      **조건**
      1. 내가 차단한 보호자와 정지된 회원의 댓글, 가려지거나 지워진 댓글은 빠집니다.
      2. `size` 는 1~50(기본 20). `cursor` 는 이전 쪽의 `nextCursor` 를 그대로 넣으며, 형식이 틀리면 첫 쪽으로 봅니다.
      3. 없거나 내려간 글이면 404 `TALK_POST_NOT_FOUND`.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "조회 성공",
      content = @Content(schema = @Schema(implementation = TalkCommentPageResponse.class))),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "404", description = "없거나 내려간 글(TALK_POST_NOT_FOUND)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<TalkCommentPageResponse> getComments(
    Authentication authentication,
    @Parameter(description = "글 id") String postId,
    @Parameter(description = "이전 쪽의 nextCursor") String cursor,
    @Parameter(description = "한 쪽 건수 1~50, 기본 20") Integer size
  );

  @Operation(
    summary = "댓글 쓰기",
    description = """
      글에 댓글을 씁니다.

      **검사**
      1. 이용 규칙에 동의하지 않았으면 403 `TALK_RULES_NOT_AGREED`.
      2. 앞뒤 공백을 지운 뒤 비었으면 400 `INVALID_INPUT_VALUE`, 300자를 넘으면 400 `TALK_TEXT_TOO_LONG`.
      3. 금칙어가 있으면 400 `TALK_TEXT_NOT_ALLOWED`.
      4. 없거나 내려간 글이면 404 `TALK_POST_NOT_FOUND`.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "쓰기 성공. 쓴 댓글",
      content = @Content(schema = @Schema(implementation = TalkCommentResponse.class))),
    @ApiResponse(responseCode = "400",
      description = "빈 댓글(INVALID_INPUT_VALUE) · 300자 초과(TALK_TEXT_TOO_LONG) · 금칙어(TALK_TEXT_NOT_ALLOWED)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "403", description = "이용 규칙 미동의(TALK_RULES_NOT_AGREED)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "404", description = "없거나 내려간 글(TALK_POST_NOT_FOUND)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<TalkCommentResponse> addComment(
    Authentication authentication, @Parameter(description = "글 id") String postId, TalkCommentRequest request);

  @Operation(
    summary = "내 댓글 지우기",
    description = """
      내가 쓴 댓글을 지웁니다.
      없거나 이미 지운 댓글이면 404 `TALK_COMMENT_NOT_FOUND`, 남의 댓글이면 403 `TALK_NOT_AUTHOR`.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "204", description = "지우기 성공"),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "403", description = "남의 댓글(TALK_NOT_AUTHOR)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "404", description = "없거나 이미 지운 댓글(TALK_COMMENT_NOT_FOUND)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<Void> deleteComment(Authentication authentication, @Parameter(description = "댓글 id") String commentId);
}
