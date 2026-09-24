package com.chuseok22.elumserver.ai.core;

/**
 * AI 호출이 무엇을 위한 것인가. 제공자와 무관한 축이다 (#367).
 *
 * <p>요금제 한도는 "일과를 몇 개 만들었나" 를 세야 하는데, {@link AiCallType} 은 제공자마다
 * 값이 따로 있다. 유형 하나를 골라 세면 제공자를 바꾸는 순간 한도가 풀린다. 그래서 유형마다
 * 목적을 붙이고, 한도는 목적으로 센다.
 */
public enum AiCallPurpose {

  /// 일과 한 개를 만드는 텍스트 호출. 요금제 한도가 세는 대상이다.
  ROUTINE_CREATE,
  /// 일과를 만들기 전에 묻는 추가 질문.
  ROUTINE_QUESTION,
  /// 카드 그림 한 장.
  CARD_IMAGE,
  /// 보호자 입력의 민감정보 검사.
  SENSITIVE_INFO_CHECK,
  /// FLUX 그림용 영어 장면 한 줄 번역 (#373). 보호자가 직접 추가한 카드처럼 글 AI 가 영어를 주지
  /// 않은 카드에만 붙는다. 일과 생성으로 세면 카드 추가 한 번이 일과 한 개로 잡혀 한도를 깎는다.
  IMAGE_PROMPT_TRANSLATE,
}
