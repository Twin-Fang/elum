package com.chuseok22.elumserver.talk.core;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;

/**
 * 이야기 글 분류 6개: 앱 RoutineTemplateCategory 와 같은 이름 (CrossStackContractTest 가 대조)
 * 요청 문자열 > 분류 (모르는 값·null 은 INVALID_INPUT_VALUE)
 */
public enum TalkCategory {

  SELF_CARE,
  DAILY_FLOW,
  HOUSEHOLD,
  COMMUNITY,
  LEARNING,
  FEELINGS,
  ;

  public static TalkCategory parse(String raw) {
    if (raw != null) {
      String trimmed = raw.trim();
      for (TalkCategory category : values()) {
        if (category.name().equals(trimmed)) {
          return category;
        }
      }
    }
    throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
  }
}
