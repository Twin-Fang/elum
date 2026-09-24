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
  // FLUX 전용 짧은 영어 화풍 지시문. 캐릭터 영어 묘사와 카드의 영어 장면 한 줄이 뒤에 붙는다 (#373).
  FLUX_ROUTINE_IMAGE_PREFIX("FLUX 그림 지시문 (영어 전용)"),
  // 영어 장면이 없는 카드(보호자가 직접 추가)를 FLUX 용 한 줄로 옮기는 지시문 (#373).
  FLUX_IMAGE_PROMPT_TRANSLATE("FLUX 그림 문장 번역"),
  ;

  private final String label;
}
