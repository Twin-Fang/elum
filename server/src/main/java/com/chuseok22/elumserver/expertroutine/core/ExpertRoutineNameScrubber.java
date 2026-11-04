package com.chuseok22.elumserver.expertroutine.core;

import com.chuseok22.elumserver.ai.core.NicknamePlaceholder;
import com.chuseok22.elumserver.common.locale.AppLocale;

/**
 * 보호자 일과 > 전문가 일과로 옮길 때 이룸이 호칭 지우기: 조사 맞춰 자리표시로 > 낱말 일부로 남은 호칭도 자리표시로
 * 다른 사람 이름(형제·선생님)은 찾지 못함 > 관리자 화면이 검수를 요구
 */
public final class ExpertRoutineNameScrubber {

  // 호칭이 이 글자 수 이상일 때만 낱말 일부까지 바꿈 (1자는 오탐이 커서 제외)
  private static final int MINIMUM_STRICT_NAME_LENGTH = 2;

  private ExpertRoutineNameScrubber() {
  }

  /// 글 > 호칭을 자리표시(ko 이룸이, 그 밖 Elumi)로 바꾼 글. 글·호칭이 비면 글 그대로
  public static String scrub(String text, String nickname, AppLocale language) {
    String masked = NicknamePlaceholder.mask(text, nickname, language);
    if (masked == null || !isStrictTarget(nickname, language)) {
      return masked;
    }
    return masked.replace(nickname.trim(), NicknamePlaceholder.placeholderFor(language));
  }

  // 자리표시가 호칭을 품으면(호칭 "이룸") 구분할 수 없어 제외
  private static boolean isStrictTarget(String nickname, AppLocale language) {
    if (nickname == null) {
      return false;
    }
    String name = nickname.trim();
    return name.codePointCount(0, name.length()) >= MINIMUM_STRICT_NAME_LENGTH
      && !NicknamePlaceholder.placeholderFor(language).contains(name);
  }
}
