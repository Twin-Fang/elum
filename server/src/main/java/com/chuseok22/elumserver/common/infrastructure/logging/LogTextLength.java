package com.chuseok22.elumserver.common.infrastructure.logging;

/**
 * 로그용 글 길이: 원문 대신 글자 수만 남김 (null > 0)
 */
public final class LogTextLength {

  private LogTextLength() {
  }

  public static int of(CharSequence text) {
    return text == null ? 0 : text.length();
  }
}
