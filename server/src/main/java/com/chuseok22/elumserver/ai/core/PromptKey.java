package com.chuseok22.elumserver.ai.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public enum PromptKey {

  LOCAL_LLM_SENSITIVE_INFO_CHECK("로컬 LLM 민감정보 검사"),
  GEMINI_ROUTINE_CREATE_PREFIX("Gemini 루틴 생성"),
  GEMINI_ROUTINE_REVISE_PREFIX("Gemini 루틴 수정"),
  GEMINI_ROUTINE_QUESTION_PREFIX("Gemini 추가 질문 생성"),
  GEMINI_ROUTINE_IMAGE_PREFIX("Gemini 이미지 프롬프트 프리픽스"),
  ;

  private final String label;
}
