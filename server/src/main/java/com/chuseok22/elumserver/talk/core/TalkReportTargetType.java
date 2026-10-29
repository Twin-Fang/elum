package com.chuseok22.elumserver.talk.core;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

/** 신고 대상 종류: 글, 댓글 (label 은 신고 메일에 쓰는 한글 이름) */
@Getter
@RequiredArgsConstructor
public enum TalkReportTargetType {

  POST("글"),
  COMMENT("댓글"),
  ;

  private final String label;
}
