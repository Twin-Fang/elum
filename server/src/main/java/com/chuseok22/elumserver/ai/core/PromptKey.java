package com.chuseok22.elumserver.ai.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public enum PromptKey {

  LOCAL_LLM_SENSITIVE_INFO_CHECK("로컬 LLM 민감정보 검사"),
  GEMINI_ROUTINE_CREATE_PREFIX("Gemini 루틴 생성"),
  GEMINI_ROUTINE_QUESTION_PREFIX("Gemini 추가 질문 생성"),
  GEMINI_ROUTINE_IMAGE_PREFIX("Gemini 이미지 프롬프트 프리픽스"),
  // 위 지시문의 영어판. OpenAI·Gemini 가 같이 쓴다. 설정 IMAGE_PROMPT_LANGUAGE=EN 일 때만 쓰인다 (#375).
  ROUTINE_IMAGE_PREFIX_EN("그림 지시문 (영어 · OpenAI/Gemini)"),
  ;

  private final String label;
}
