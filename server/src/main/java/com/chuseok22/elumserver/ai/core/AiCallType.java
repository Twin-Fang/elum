package com.chuseok22.elumserver.ai.core;

import java.util.Arrays;
import java.util.EnumSet;
import java.util.Set;
import lombok.AllArgsConstructor;
import lombok.Getter;

// AI 호출 로그의 호출 유형. 관리자 모니터링 화면의 필터와 비용 계산 방식 결정에 쓴다.
// 목적(purpose)은 생성자 인자라 새 유형을 더할 때 빠뜨리면 컴파일이 막힌다 (#367).
@Getter
@AllArgsConstructor
public enum AiCallType {

  GEMINI_TEXT_CREATE("Gemini 루틴 생성", AiCallPurpose.ROUTINE_CREATE),
  GEMINI_TEXT_QUESTION("Gemini 추가 질문", AiCallPurpose.ROUTINE_QUESTION),
  GEMINI_IMAGE("Gemini 이미지", AiCallPurpose.CARD_IMAGE),
  OPENAI_TEXT_CREATE("OpenAI 루틴 생성", AiCallPurpose.ROUTINE_CREATE),
  OPENAI_TEXT_QUESTION("OpenAI 추가 질문", AiCallPurpose.ROUTINE_QUESTION),
  OPENAI_IMAGE("OpenAI 이미지", AiCallPurpose.CARD_IMAGE),
  FLUX_IMAGE("FLUX 이미지", AiCallPurpose.CARD_IMAGE),
  LOCAL_LLM_DLP("로컬 LLM 민감정보 검사", AiCallPurpose.SENSITIVE_INFO_CHECK),
  ;

  private final String label;
  private final AiCallPurpose purpose;

  /**
   * 일과 생성으로 세는 유형 전부. 요금제 한도가 이 목록으로 센다.
   *
   * <p>유형 하나({@code GEMINI_TEXT_CREATE})만 세면 텍스트 제공자를 OpenAI 로 바꾸는 순간
   * 사용량이 0 으로 세져 한도가 풀린다 (#367). 목적으로 모아 두면 제공자가 늘어도 따라온다.
   */
  public static Set<AiCallType> routineCreateTypes() {
    return ofPurpose(AiCallPurpose.ROUTINE_CREATE);
  }

  private static Set<AiCallType> ofPurpose(AiCallPurpose purpose) {
    EnumSet<AiCallType> types = EnumSet.noneOf(AiCallType.class);
    Arrays.stream(values()).filter(type -> type.purpose == purpose).forEach(types::add);
    return types;
  }
}
