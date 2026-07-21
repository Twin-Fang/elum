package com.chuseok22.elumserver.ai.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public enum PromptKey {

  LOCAL_LLM_SENSITIVE_INFO_CHECK("로컬 LLM 민감정보 검사"),
  GEMINI_ROUTINE_TEXT_PREFIX("Gemini 텍스트(단계) 생성"),
  GEMINI_ROUTINE_IMAGE_PREFIX("Gemini 이미지 프롬프트 프리픽스"),
  GEMINI_ROUTINE_QUESTION_PREFIX("Gemini 추가 질문 생성"),
  ;

  private final String label;
}
