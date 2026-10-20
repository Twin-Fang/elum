package com.chuseok22.elumserver.talk.core;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;

/**
 * 이야기 글·댓글 글자 규칙: 길이 상한, 한마디 정리
 */
public final class TalkTextRules {

  // 한마디 최대 글자 수 (코드포인트 기준)
  public static final int MAX_NOTE_LENGTH = 300;
  // 댓글 최대 글자 수 (코드포인트 기준)
  public static final int MAX_COMMENT_LENGTH = 300;

  private TalkTextRules() {

  }

  /**
   * 한마디 정리: 제어문자 제거(줄바꿈 제외) > 앞뒤 공백 제거 > 빈 값은 null > 길이 검사
   *
   * @throws CustomException 300자 초과는 TALK_TEXT_TOO_LONG
   */
  public static String normalizeNote(String raw) {
    if (raw == null) {
      return null;
    }
    StringBuilder cleaned = new StringBuilder(raw.length());
    raw.codePoints()
      .filter(codePoint -> codePoint == '\n' || !Character.isISOControl(codePoint))
      .forEach(cleaned::appendCodePoint);
    String note = cleaned.toString().strip();
    if (note.isEmpty()) {
      return null;
    }
    if (note.codePointCount(0, note.length()) > MAX_NOTE_LENGTH) {
      throw new CustomException(ErrorCode.TALK_TEXT_TOO_LONG);
    }
    return note;
  }
}
