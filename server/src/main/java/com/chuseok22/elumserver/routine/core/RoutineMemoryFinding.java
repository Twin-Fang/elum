package com.chuseok22.elumserver.routine.core;

import java.util.Locale;
import java.util.Objects;

/**
 * 보호자가 고친 것 하나: 종류 + 바꾸기 전·후 낱말(없으면 null) + 한 줄 요약
 * 같은 수정인지는 (종류, before, after) 로만 가름 (요약 글은 보지 않음)
 */
public record RoutineMemoryFinding(RoutineMemoryRuleType type, String before, String after, String summary) {

  /// 같은 수정 판별 열쇠: 종류 + before + after (앞뒤 공백·대소문자 무시)
  public String identityKey() {
    return type + "\n" + normalize(before) + "\n" + normalize(after);
  }

  public static String identityKeyOf(RoutineMemoryRuleType type, String before, String after) {
    return new RoutineMemoryFinding(type, before, after, null).identityKey();
  }

  private static String normalize(String text) {
    return Objects.toString(text, "").trim().toLowerCase(Locale.ROOT);
  }
}
