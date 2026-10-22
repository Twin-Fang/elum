package com.chuseok22.elumserver.talk.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDateTime;

@Schema(description = "이야기 댓글 1건. 쓴 사람의 회원 id·이메일은 담지 않는다")
public record TalkCommentResponse(
  @Schema(description = "댓글 id")
  String id,
  @Schema(description = "쓴 사람 닉네임. 닉네임이 없는 계정은 null")
  String authorNickname,
  @Schema(description = "내가 쓴 댓글인가")
  boolean isMine,
  @Schema(description = "댓글 내용. 관리자가 가린 댓글은 빈 문자열")
  String body,
  @Schema(description = "쓴 시각")
  LocalDateTime createdAt,
  @Schema(description = "관리자가 가린 내 댓글인가. 가린 댓글은 쓴 사람 본인에게만 내려간다")
  boolean isHidden,
  @Schema(description = "이 글을 올린 보호자가 쓴 댓글인가 (댓글 칸 이름 뒤 '(글쓴이)')")
  boolean isPostAuthor
) {

}
