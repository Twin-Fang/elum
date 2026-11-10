package com.chuseok22.elumserver.ai.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * AI 호출이 무엇을 위한 것인가. 제공자와 무관한 축이다.
 *
 * <p>요금제 한도는 "일과를 몇 개 만들었나" 를 세야 하는데, {@link AiCallType} 은 제공자마다
 * 값이 따로 있다. 유형 하나를 골라 세면 제공자를 바꾸는 순간 한도가 풀린다. 그래서 유형마다
 * 목적을 붙이고, 한도는 목적으로 센다.
 */
@Getter
@AllArgsConstructor
public enum AiCallPurpose {

  /// 일과 한 개를 만드는 텍스트 호출. 요금제 한도가 세는 대상이다.
  ROUTINE_CREATE("일과 생성"),
  /// 일과를 만들기 전에 묻는 추가 질문.
  ROUTINE_QUESTION("추가 질문"),
  /// 카드 그림 한 장.
  CARD_IMAGE("카드 그림"),
  /// 보호자 입력의 민감정보 검사.
  SENSITIVE_INFO_CHECK("민감정보 검사"),
  /// FLUX 그림용 영어 장면 한 줄 번역. 보호자가 직접 추가한 카드처럼 글 AI 가 영어를 주지
  /// 않은 카드에만 붙는다. 일과 생성으로 세면 카드 추가 한 번이 일과 한 개로 잡혀 한도를 깎는다.
  IMAGE_PROMPT_TRANSLATE("그림 문장 번역"),
  /// 직접 추가한 카드에 무료 픽토그램 id 를 고르는 글 호출. 일과 생성으로 세면 카드 추가 한 번이
  /// 일과 한 개로 잡혀 한도를 깎는다.
  PICTOGRAM_PICK("픽토그램 선택"),
  /// 지운 기능(일과 번역)의 목적. 새로 기록하지 않음, 저장된 호출 로그를 읽기 위해 남김
  ROUTINE_TRANSLATE("일과 번역"),
  /// 이룸이별 AI 메모 갱신 (#1082, Pro). 하루 1번 묶어 부름. 일과 생성으로 세면 한도를 깎는다.
  ROUTINE_MEMORY("AI 메모 갱신"),
  /// 주간 리포트 정리 글. 일과 생성 한도에는 세지 않고 하루 AI 비용 합계에만 센다. 크레딧 없음
  WEEKLY_REPORT_SUMMARY("주간 리포트 정리"),
  ;

  /// 관리자 그래프 범례 이름
  private final String label;
}
