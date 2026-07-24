package com.chuseok22.elumserver.systemconfig.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

// 관리자 시스템 설정 화면에서 카드 단위로 묶어 보여주기 위한 설정 그룹.
@Getter
@AllArgsConstructor
public enum ConfigGroup {

  GEMINI_TEXT("Gemini 텍스트"),
  GEMINI_IMAGE("Gemini 이미지"),
  LOCAL_LLM("로컬 LLM"),
  PRICING("AI 요금 단가"),
  ;

  private final String label;
}
