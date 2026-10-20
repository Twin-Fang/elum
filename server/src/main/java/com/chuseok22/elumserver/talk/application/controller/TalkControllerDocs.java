package com.chuseok22.elumserver.talk.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.talk.application.dto.request.TalkPostCreateRequest;
import com.chuseok22.elumserver.talk.application.dto.request.TalkPreviewRequest;
import com.chuseok22.elumserver.talk.application.dto.response.TalkFeedPageResponse;
import com.chuseok22.elumserver.talk.application.dto.response.TalkPostCreatedResponse;
import com.chuseok22.elumserver.talk.application.dto.response.TalkPostDetailResponse;
import com.chuseok22.elumserver.talk.application.dto.response.TalkPostSummaryResponse;
import com.chuseok22.elumserver.talk.application.dto.response.TalkPreviewResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;

@Tag(
  name = "Talk",
  description = "이야기: 보호자끼리 일과를 나누는 글 API. 보호자 accessToken(Bearer) 인증이 필요하며 "
    + "이룸이 권한으로는 부를 수 없습니다. 프로필 헤더(X-Profile-Id)는 필요 없습니다."
)
public interface TalkControllerDocs {

  @Operation(
    summary = "이야기 피드",
    description = """
      보이는 글을 최신순으로 한 쪽 돌려줍니다.

      **조건**
      1. 요청의 `Accept-Language` 와 같은 언어로 올라온 글만 보입니다.
      2. 내가 차단한 보호자와 정지된 회원의 글은 빠집니다.
      3. `category` 를 비우면 전체, 값이 있으면 6개 분류 중 하나여야 합니다. 모르는 값이면 400 `INVALID_INPUT_VALUE`.
      4. `size` 는 1~50(기본 20). `cursor` 는 이전 쪽의 `nextCursor` 를 그대로 넣으며, 형식이 틀리면 첫 쪽으로 봅니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "조회 성공",
      content = @Content(schema = @Schema(implementation = TalkFeedPageResponse.class))),
    @ApiResponse(responseCode = "400", description = "모르는 분류(INVALID_INPUT_VALUE)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<TalkFeedPageResponse> getFeed(
    Authentication authentication,
    @Parameter(description = "분류. 비우면 전체") String category,
    @Parameter(description = "이전 쪽의 nextCursor") String cursor,
    @Parameter(description = "한 쪽 건수 1~50, 기본 20") Integer size
  );

  @Operation(
    summary = "인기 글",
    description = """
      최근 7일 동안 일과관리로 가져간 **고유 보호자 수**가 많은 글을 최대 10개 돌려줍니다.
      가져간 기록이 없는 글은 나오지 않으며, 언어·차단·정지 조건은 피드와 같습니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "조회 성공",
      content = @Content(schema = @Schema(implementation = TalkPostSummaryResponse.class))),
    @ApiResponse(responseCode = "400", description = "모르는 분류(INVALID_INPUT_VALUE)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<List<TalkPostSummaryResponse>> getPopular(
    Authentication authentication, @Parameter(description = "분류. 비우면 전체") String category);

  @Operation(
    summary = "내가 나눈 일과 매핑",
    description = """
      내가 올린 보이는 글을 `{ 원본 일과 id: 글 id }` 로 돌려줍니다.
      앱이 일과 목록에서 이미 나눈 일과를 가리는 데 씁니다. 원본이 없는 글은 빠집니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "조회 성공 (없으면 빈 객체)"),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<Map<String, String>> getMySharedPosts(Authentication authentication);

  @Operation(
    summary = "글 상세",
    description = """
      글과 카드 목록, 내가 도움이 됐어요를 눌렀는지·일과관리로 가져갔는지를 돌려줍니다.
      내려간 글, 내가 차단한 보호자의 글, 정지된 회원의 글은 404 `TALK_POST_NOT_FOUND`.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "조회 성공",
      content = @Content(schema = @Schema(implementation = TalkPostDetailResponse.class))),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "404", description = "글 없음·내려감·차단·정지(TALK_POST_NOT_FOUND)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<TalkPostDetailResponse> getDetail(
    Authentication authentication, @Parameter(description = "글 id") String postId);

  @Operation(
    summary = "카드 그림",
    description = """
      글 전용으로 복사해 둔 카드 그림을 내려줍니다(`Cache-Control: private, max-age=86400`).
      카드 정보의 `hasImage` 가 true 일 때만 부르면 됩니다.
      내려간 글, 없는 카드, 그림이 없는 카드는 404 `TALK_IMAGE_NOT_FOUND`.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "그림 바이트(image/jpeg·png·webp)"),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "404", description = "그림 없음(TALK_IMAGE_NOT_FOUND)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<byte[]> getStepImage(
    Authentication authentication,
    @Parameter(description = "글 id") String postId,
    @Parameter(description = "카드 순서(0부터)") int stepOrder);

  @Operation(
    summary = "이야기 올리기 미리보기",
    description = """
      올리기 전에 이룸이 이름을 가린 글과 사진 카드 여부를 보여줍니다. 저장하지 않습니다.
      나눌 수 없는 일과면 400 `TALK_ROUTINE_NOT_SHAREABLE`.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "미리보기 성공",
      content = @Content(schema = @Schema(implementation = TalkPreviewResponse.class))),
    @ApiResponse(responseCode = "400", description = "나눌 수 없는 일과(TALK_ROUTINE_NOT_SHAREABLE)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<TalkPreviewResponse> preview(Authentication authentication, TalkPreviewRequest request);

  @Operation(
    summary = "이야기 올리기",
    description = """
      일과를 글로 올립니다.

      **검사**
      1. 이용 규칙에 동의하지 않았으면 403 `TALK_RULES_NOT_AGREED`.
      2. 분류가 6개 중 하나가 아니면 400 `INVALID_INPUT_VALUE`.
      3. 나눌 수 없는 일과면 400 `TALK_ROUTINE_NOT_SHAREABLE`, 이미 나눈 일과면 409 `TALK_ALREADY_SHARED`.
      4. 금칙어가 있으면 400 `TALK_TEXT_NOT_ALLOWED`, 한마디가 길면 400 `TALK_TEXT_TOO_LONG`.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "올리기 성공",
      content = @Content(schema = @Schema(implementation = TalkPostCreatedResponse.class))),
    @ApiResponse(responseCode = "400",
      description = "분류 오류(INVALID_INPUT_VALUE) · 나눌 수 없음(TALK_ROUTINE_NOT_SHAREABLE) · "
        + "금칙어(TALK_TEXT_NOT_ALLOWED) · 한마디 초과(TALK_TEXT_TOO_LONG)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "403", description = "이용 규칙 미동의(TALK_RULES_NOT_AGREED)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "409", description = "이미 나눈 일과(TALK_ALREADY_SHARED)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<TalkPostCreatedResponse> create(Authentication authentication, TalkPostCreateRequest request);
}
