package com.chuseok22.elumserver.routine.core;

/**
 * 카드 글 길이 상한 단일 원본: 카드 추가·수정 요청, 카드 나누기 검증
 * 설명은 이룸이 화면에서 소리로 읽히므로 길이를 제한 (앱 입력 칸과 같은 값)
 */
public final class RoutineStepTextLimits {

  /// 카드 제목 최대 글자 수
  public static final int TITLE_MAX_LENGTH = 100;
  /// 카드 설명 최대 글자 수
  public static final int DESCRIPTION_MAX_LENGTH = 300;

  private RoutineStepTextLimits() {
  }
}
