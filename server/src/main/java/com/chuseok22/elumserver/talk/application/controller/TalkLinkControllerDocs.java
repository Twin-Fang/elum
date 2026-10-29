package com.chuseok22.elumserver.talk.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.talk.application.dto.request.TalkLinkCreateRequest;
import com.chuseok22.elumserver.talk.application.dto.response.TalkLinkResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;

@Tag(
  name = "Talk Link",
  description = "일과를 링크로 보내기 API. 링크 글은 피드·인기·내 글 목록에 오르지 않고 링크를 가진 사람만 봅니다. "
    + "보호자 accessToken(Bearer) 인증이 필요하며 프로필 헤더(X-Profile-Id)는 필요 없습니다. "
    + "받은 사람의 상세·가져가기는 /api/talk/posts/{postId} 와 /api/talk/posts/{postId}/import 를 그대로 씁니다."
)
public interface TalkLinkControllerDocs {

  @Operation(
    summary = "링크 만들기",
    description = """
      내가 만든 일과를 링크 글로 만듭니다. 웹 링크는 `{공유 기준 주소}/s/{postId}` 입니다.

      **규칙**
      1. 남이 만든 일과면 403 `TALK_LINK_ROUTINE_NOT_MINE`.
      2. 예시 일과·일과관리에서 지운 일과·이야기나 링크에서 가져온 일과·승인 전 일과면 400 `TALK_LINK_ROUTINE_NOT_SHAREABLE`.
      3. 같은 일과의 켜진 링크가 있으면 새로 만들지 않고 그 링크를 돌려줍니다 (`isReused=true`).
      4. 이룸이 호칭은 자리표시로 가립니다. 가리지 못하면 500 `TALK_NICKNAME_MASK_FAILED`.
      5. 만료는 없습니다. 끄기는 `DELETE /api/talk/posts/{postId}` 이며 끈 링크는 다시 켜지지 않습니다.
      6. 원본 일과를 일과관리에서 지우거나 보낸 사람이 그 이룸이 연결에서 빠지면 링크는 꺼진 것으로 봅니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "만들기 성공 또는 켜진 링크 재사용",
      content = @Content(schema = @Schema(implementation = TalkLinkResponse.class))),
    @ApiResponse(responseCode = "400",
      description = "일과 id 없음(INVALID_INPUT_VALUE) · 보낼 수 없는 일과(TALK_LINK_ROUTINE_NOT_SHAREABLE) · 금칙어(TALK_TEXT_NOT_ALLOWED)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "403", description = "남이 만든 일과(TALK_LINK_ROUTINE_NOT_MINE) · 연결 없는 이룸이",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "409", description = "같은 일과의 링크를 동시에 만듦(TALK_ALREADY_SHARED). 다시 부르면 그 링크를 받는다",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<TalkLinkResponse> create(Authentication authentication, TalkLinkCreateRequest request);

  @Operation(
    summary = "내 켜진 링크",
    description = """
      내가 만든 켜진 링크를 `{ 원본 일과 id: 링크 글 id }` 로 돌려줍니다.
      앱이 일과관리 메뉴에서 `링크 끄기` 줄을 보일지 정하는 데 씁니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "조회 성공 (없으면 빈 객체)"),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<Map<String, String>> getMyLinks(Authentication authentication);
}
