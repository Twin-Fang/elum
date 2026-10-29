package com.chuseok22.elumserver.talk.core;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

/** 댓글 상태: 보임, 관리자가 가림, 작성자가 지움 (label 은 관리자 화면 한글 이름) */
@Getter
@RequiredArgsConstructor
public enum TalkCommentStatus {

  VISIBLE("보이는 댓글"),
  HIDDEN_BY_ADMIN("가린 댓글"),
  DELETED("지운 댓글"),
  ;

  private final String label;
}
