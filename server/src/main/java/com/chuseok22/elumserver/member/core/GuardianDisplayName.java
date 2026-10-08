package com.chuseok22.elumserver.member.core;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;

/**
 * 함께하는 사람을 부르는 이름의 규칙.
 *
 * <p>request DTO 에 검증 어노테이션을 달지 않는 저장소 규칙이라 길이·문자를 여기서 막는다. 다른 보호자와 이룸이 폰
 * 화면에 그대로 나가는 값이므로 줄바꿈·제어 문자는 받지 않는다.
 */
public final class GuardianDisplayName {

  /** 사람이 읽는 글자 수(유니코드 코드포인트) 기준. 컬럼은 30 이라 넉넉하다. */
  public static final int MAX_LENGTH = 20;

  private GuardianDisplayName() {
  }

  /**
   * 입력을 저장할 값으로 맞춘다. 앞뒤 공백을 자르고, 비었으면 null(이름 없음).
   *
   * @throws CustomException 너무 길거나 제어 문자가 섞였으면 INVALID_INPUT_VALUE
   */
  public static String normalize(String raw) {
    if (raw == null) {
      return null;
    }
    String trimmed = raw.strip();
    if (trimmed.isEmpty()) {
      return null;
    }
    if (trimmed.codePointCount(0, trimmed.length()) > MAX_LENGTH
      || trimmed.codePoints().anyMatch(Character::isISOControl)) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    return trimmed;
  }
}
