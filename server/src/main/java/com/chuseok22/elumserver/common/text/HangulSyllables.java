package com.chuseok22.elumserver.common.text;

/**
 * 한글 음절 받침 판정: 한글 음절 여부, 받침 있음, ㄹ받침 (한글 음절이 아니면 받침 없음)
 * 음절 = (초성, 중성, 종성) 조합 > (글자 - 가) % 28 = 종성 자리 (0 받침 없음, 8 ㄹ)
 */
public final class HangulSyllables {

  // 한글 음절 범위: 가(U+AC00) ~ 힣(U+D7A3)
  private static final char FIRST_SYLLABLE = '가';
  private static final char LAST_SYLLABLE = '힣';
  // 종성 자리 28칸, ㄹ 은 8번째
  private static final int JONGSEONG_COUNT = 28;
  private static final int RIEUL_JONGSEONG_INDEX = 8;

  private HangulSyllables() {
  }

  public static boolean isHangulSyllable(char character) {
    return character >= FIRST_SYLLABLE && character <= LAST_SYLLABLE;
  }

  public static boolean hasJongseong(char character) {
    return jongseongIndexOf(character) != 0;
  }

  public static boolean hasRieulJongseong(char character) {
    return jongseongIndexOf(character) == RIEUL_JONGSEONG_INDEX;
  }

  // 한글 음절 아님 > 0 (받침 없음으로 봄)
  private static int jongseongIndexOf(char character) {
    return isHangulSyllable(character) ? (character - FIRST_SYLLABLE) % JONGSEONG_COUNT : 0;
  }
}
