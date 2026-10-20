package com.chuseok22.elumserver.ai.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * AI 호출 대상 회사. 이름은 시스템 설정 제공자 선택값(IMAGE_PROVIDER_SELECTED 등)과 같다
 */
@Getter
@AllArgsConstructor
public enum AiProvider {

  GEMINI("Gemini"),
  OPENAI("OpenAI"),
  FLUX("FLUX"),
  LOCAL_LLM("로컬 LLM"),
  ;

  private final String label;

  /** 제공자 줄 이름 (Gemini 글, OpenAI 그림) */
  public String laneLabel(boolean isImage) {
    return label + (isImage ? " 그림" : " 글");
  }

  /** 설정 선택값 > 제공자 (모르는 값은 null) */
  public static AiProvider fromConfigValue(String value) {
    if (value == null) {
      return null;
    }
    for (AiProvider provider : values()) {
      if (provider.name().equalsIgnoreCase(value.trim())) {
        return provider;
      }
    }
    return null;
  }
}
