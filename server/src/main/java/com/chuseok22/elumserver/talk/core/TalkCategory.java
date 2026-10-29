package com.chuseok22.elumserver.talk.core;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import lombok.Getter;
import lombok.RequiredArgsConstructor;

/**
 * 이야기 글 분류 6개: 앱 RoutineTemplateCategory 와 같은 이름 (CrossStackContractTest 가 대조)
 * 요청 문자열 > 분류 (모르는 값·null 은 INVALID_INPUT_VALUE), 분류 > 관리자 화면 한글 라벨
 */
@Getter
@RequiredArgsConstructor
public enum TalkCategory {

  SELF_CARE("생활 습관"),
  DAILY_FLOW("하루 순서"),
  HOUSEHOLD("집안일"),
  COMMUNITY("바깥 활동"),
  LEARNING("공부"),
  FEELINGS("감정·관계"),
  ;

  // 관리자 화면 표시 이름 (앱 문구와 별개)
  private final String label;

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
