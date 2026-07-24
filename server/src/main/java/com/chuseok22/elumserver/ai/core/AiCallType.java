package com.chuseok22.elumserver.ai.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

// AI 호출 로그의 호출 유형. 관리자 모니터링 화면의 필터와 비용 계산 방식 결정에 쓴다.
@Getter
@AllArgsConstructor
public enum AiCallType {

  GEMINI_TEXT_CREATE("Gemini 루틴 생성"),
  GEMINI_TEXT_QUESTION("Gemini 추가 질문"),
  GEMINI_IMAGE("Gemini 이미지"),
  LOCAL_LLM_DLP("로컬 LLM 민감정보 검사"),
  ;

  private final String label;
}
