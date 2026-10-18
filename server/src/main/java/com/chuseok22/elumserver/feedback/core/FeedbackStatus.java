package com.chuseok22.elumserver.feedback.core;

import java.util.Optional;
import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 의견 처리 상태: 새 의견, 확인 중, 처리 완료
 * 어느 상태로든 바꿀 수 있음 (처리 완료 > 새 의견으로 되돌려 다시 열기 포함)
 */
@Getter
@AllArgsConstructor
public enum FeedbackStatus {

  NEW("새 의견"),
  IN_PROGRESS("확인 중"),
  DONE("처리 완료"),
  ;

  private final String label;

  /** 화면에서 넘어온 이름 > 상태 (알 수 없는 값은 빈 값) */
  public static Optional<FeedbackStatus> fromName(String name) {
    if (name == null) {
      return Optional.empty();
    }
    for (FeedbackStatus status : values()) {
      if (status.name().equals(name.trim())) {
        return Optional.of(status);
      }
    }
    return Optional.empty();
  }
}
