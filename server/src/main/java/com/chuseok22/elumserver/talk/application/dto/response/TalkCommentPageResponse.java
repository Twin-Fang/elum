package com.chuseok22.elumserver.talk.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

@Schema(description = "이야기 댓글 한 쪽")
public record TalkCommentPageResponse(
  @Schema(description = "댓글 목록(오래된 순)")
  List<TalkCommentResponse> items,
  @Schema(description = "다음 쪽을 받을 cursor. 더 없으면 null")
  String nextCursor
) {

}
