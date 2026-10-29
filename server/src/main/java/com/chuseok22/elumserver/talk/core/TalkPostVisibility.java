package com.chuseok22.elumserver.talk.core;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

/** 글 공개 범위: 공개(피드·인기·내 글 목록에 보임), 링크로만(링크를 가진 사람만 상세·가져가기, label 은 관리자 화면 한글 이름) */
@Getter
@RequiredArgsConstructor
public enum TalkPostVisibility {

  PUBLIC("공개 글"),
  LINK_ONLY("링크 글"),
  ;

  private final String label;
}
