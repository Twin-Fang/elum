package com.chuseok22.elumserver.migration.core;

import java.util.Arrays;
import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 동기화 결과 4개 + 모름: sync-status.json 의 result 값 > 표시 이름, 배지 색 (#1062)
 * tone: 배지 색 이름 (success·error·warning·info·ghost > 배지 클래스: admin-ui.html toneBadge)
 */
@Getter
@AllArgsConstructor
public enum MigrationSyncResult {

  SUCCESS("success", "정상", "success"),
  FAILED("failed", "실패", "error"),
  SKIPPED("skipped", "건너뜀", "warning"),
  RUNNING("running", "진행 중", "info"),
  UNKNOWN("", "알 수 없음", "ghost"),
  ;

  private final String code;
  private final String label;
  private final String tone;

  /// result 값 > 결과 (없거나 모르는 값은 UNKNOWN)
  public static MigrationSyncResult fromCode(String code) {
    return Arrays.stream(values())
      .filter(result -> result != UNKNOWN && result.code.equals(code))
      .findFirst()
      .orElse(UNKNOWN);
  }
}
