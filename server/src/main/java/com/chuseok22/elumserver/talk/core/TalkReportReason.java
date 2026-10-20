package com.chuseok22.elumserver.talk.core;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

/** 신고 사유: 개인정보, 불쾌한 내용, 광고, 기타 (label 은 신고 메일에 쓰는 한글 이름) */
@Getter
@RequiredArgsConstructor
public enum TalkReportReason {

  PERSONAL_INFO("개인정보 노출"),
  OFFENSIVE("불쾌한 내용"),
  ADVERTISING("광고"),
  OTHER("기타"),
  ;

  private final String label;
}
