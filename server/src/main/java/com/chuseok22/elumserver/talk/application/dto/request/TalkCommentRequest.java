package com.chuseok22.elumserver.talk.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;

/// 검증 어노테이션을 쓰지 않는다. 빈 값·길이·금칙어 검사는 TalkReactionService 가 CustomException 으로 던진다.
@Schema(description = "이야기 댓글 쓰기 요청")
public record TalkCommentRequest(
  @Schema(description = "댓글 내용. 앞뒤 공백은 지우며 비면 400, 최대 300자(코드포인트)", example = "저도 따라 해 봤어요")
  String body
) {

}
