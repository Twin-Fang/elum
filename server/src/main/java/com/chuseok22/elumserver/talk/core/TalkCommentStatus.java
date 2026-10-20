package com.chuseok22.elumserver.talk.core;

/** 댓글 상태: 보임, 관리자가 가림, 작성자가 지움 */
public enum TalkCommentStatus {

  VISIBLE,
  HIDDEN_BY_ADMIN,
  DELETED,
  ;
}
