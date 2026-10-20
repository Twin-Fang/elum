package com.chuseok22.elumserver.talk.core;

/** 글 상태: 보임, 관리자가 가림, 작성자가 지움 (가림·지움은 목록·상세에서 빠짐) */
public enum TalkPostStatus {

  VISIBLE,
  HIDDEN_BY_ADMIN,
  DELETED,
  ;
}
