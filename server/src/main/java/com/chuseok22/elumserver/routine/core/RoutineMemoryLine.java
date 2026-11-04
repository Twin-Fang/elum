package com.chuseok22.elumserver.routine.core;

/**
 * AI 메모 한 줄 (#1082)
 *
 * @param text   해요체 한 문장 (최대 60자, 금지 낱말 거른 뒤)
 * @param source AI: 메모 갱신이 만든 줄 / GUARDIAN: 보호자가 쓰거나 고친 줄 (갱신이 덮어쓰지 않음)
 */
public record RoutineMemoryLine(String text, Source source) {

  /// 이룸이 1명당 최대 줄 수 (프롬프트 토큰 제한)
  public static final int MAX_LINES = 10;

  public enum Source {
    AI,
    GUARDIAN
  }
}
