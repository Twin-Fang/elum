package com.chuseok22.elumserver.talk.core;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

/** 글 상태: 보임, 관리자가 가림, 작성자가 지움 (가림·지움은 목록·상세에서 빠짐, label 은 관리자 화면 한글 이름) */
@Getter
@RequiredArgsConstructor
public enum TalkPostStatus {

  VISIBLE("보이는 글"),
  HIDDEN_BY_ADMIN("가린 글"),
  DELETED("지운 글"),
  ;

  private final String label;
}
