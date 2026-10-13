package com.chuseok22.elumserver.link.core;

/**
 * 이룸이 휴대폰의 기기 이름(모델명) 규칙.
 *
 * <p>연결 암호 넣기는 인증 없이 열려 있고 이 값이 보호자 화면에 그대로 나간다. 그래서 제어 문자는 빼고
 * 길이는 잘라 저장한다. 부가 정보라 연결 자체를 막지 않으므로 거부하지 않고 정리한다.
 */
public final class DeviceName {

  /** 사람이 읽는 글자 수(코드포인트). 컬럼은 60 이라 넉넉하다. */
  public static final int MAX_LENGTH = 40;

  private DeviceName() {
  }

  /** 제어 문자를 빼고 앞뒤 공백을 자른 뒤 길이를 맞춘다. 비면 null. */
  public static String sanitize(String raw) {
    if (raw == null) {
      return null;
    }
    StringBuilder sb = new StringBuilder();
    raw.codePoints().filter(cp -> !Character.isISOControl(cp)).forEach(sb::appendCodePoint);
    String cleaned = sb.toString().strip();
    if (cleaned.isEmpty()) {
      return null;
    }
    if (cleaned.codePointCount(0, cleaned.length()) > MAX_LENGTH) {
      cleaned = cleaned.substring(0, cleaned.offsetByCodePoints(0, MAX_LENGTH)).strip();
    }
    return cleaned.isEmpty() ? null : cleaned;
  }
}
