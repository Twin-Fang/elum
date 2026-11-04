package com.chuseok22.elumserver.migration.core;

import java.util.Arrays;
import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 정합성 검사 결과 3개 + 모름: verify-status.json 의 result 값 > 표시 이름, 배지 색 (#1062)
 * tone: 배지 색 이름 (success·error·warning·ghost > 배지 클래스: admin-ui.html toneBadge)
 */
@Getter
@AllArgsConstructor
public enum MigrationVerifyResult {

  CONSISTENT("consistent", "차이 없음", "success"),
  DIFFERENT("different", "차이 있음", "warning"),
  FAILED("failed", "검사 실패", "error"),
  UNKNOWN("", "알 수 없음", "ghost"),
  ;

  private final String code;
  private final String label;
  private final String tone;

  /// result 값 > 결과 (없거나 모르는 값은 UNKNOWN)
  public static MigrationVerifyResult fromCode(String code) {
    return Arrays.stream(values())
      .filter(result -> result != UNKNOWN && result.code.equals(code))
      .findFirst()
      .orElse(UNKNOWN);
  }
}
