package com.chuseok22.elumserver.member.core;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;

/**
 * 이룸이 호칭 규칙: 길이 상한, 줄바꿈·제어 문자 거절 (#1129)
 * request DTO 에 검증 어노테이션을 달지 않는 저장소 규칙이라 여기서 막음. 클라 `ElumiNicknamePolicy.maxLength` 와 같은 값
 */
public final class ElumiNickname {

  /** 글자 수 상한 (코드포인트). 이룸이 화면 보상 문구·인사말에 그대로 나감. 컬럼은 255 */
  public static final int MAX_LENGTH = 20;

  private ElumiNickname() {
  }

  /**
   * 입력 > 저장할 값 (앞뒤 공백 제거). null 이면 null
   *
   * @throws CustomException 너무 길거나 제어 문자가 섞였으면 INVALID_INPUT_VALUE
   */
  public static String normalize(String raw) {
    if (raw == null) {
      return null;
    }
    String trimmed = raw.strip();
    if (trimmed.codePointCount(0, trimmed.length()) > MAX_LENGTH
      || trimmed.codePoints().anyMatch(Character::isISOControl)) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    return trimmed;
  }
}
