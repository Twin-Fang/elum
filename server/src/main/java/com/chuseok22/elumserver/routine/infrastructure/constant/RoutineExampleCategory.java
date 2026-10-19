package com.chuseok22.elumserver.routine.infrastructure.constant;

/**
 * 온보딩 예시 일과 분류 4개 (#803). name 이 API 코드다 — 클라 `RoutineExampleCategory.apiValue` 와 같아야 한다.
 */
public enum RoutineExampleCategory {
  MORNING_EVENING,
  SCHOOL_STUDY,
  HOUSE_SELF,
  OUTSIDE;

  /** API 코드 > 분류. 모르는 코드·null 이면 null */
  public static RoutineExampleCategory fromCode(String code) {
    if (code == null) {
      return null;
    }
    for (RoutineExampleCategory category : values()) {
      if (category.name().equals(code.trim())) {
        return category;
      }
    }
    return null;
  }
}
