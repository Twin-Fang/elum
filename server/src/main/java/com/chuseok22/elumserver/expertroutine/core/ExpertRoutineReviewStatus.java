package com.chuseok22.elumserver.expertroutine.core;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

/**
 * 전문가 일과 검수 상태 2개: 초안(검수 전, 공개 불가), 검수 완료(공개 가능)
 * 관리자 화면 라벨만 들고 있음 (앱에는 나가지 않음)
 */
@Getter
@RequiredArgsConstructor
public enum ExpertRoutineReviewStatus {

  DRAFT("초안, 전문가 검수 필요"),
  REVIEWED("검수 완료"),
  ;

  private final String label;

  /// 요청 문자열 > 상태 (모르는 값·null 은 초안: 공개를 막는 쪽으로 기움)
  public static ExpertRoutineReviewStatus parseOrDraft(String raw) {
    if (raw != null) {
      for (ExpertRoutineReviewStatus status : values()) {
        if (status.name().equals(raw.trim())) {
          return status;
        }
      }
    }
    return DRAFT;
  }
}
