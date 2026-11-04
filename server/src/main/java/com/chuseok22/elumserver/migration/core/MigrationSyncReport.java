package com.chuseok22.elumserver.migration.core;

import java.time.LocalDateTime;
import java.util.List;

/**
 * NAS 마지막 동기화 결과 (sync-status.json, #1062)
 * 시각은 이 서버 시간대 값, 값이 없던 칸은 null
 */
public record MigrationSyncReport(
  LocalDateTime startedAt,
  LocalDateTime finishedAt,
  MigrationSyncResult result,
  String rawResult,
  Long durationSeconds,
  // schedule 정기 실행, request 관리자 요청
  String trigger,
  // NAS 스크립트가 남긴 짧은 영어 문구
  String message,
  // 마지막 로그 몇 줄 (줄 수·길이 상한은 MigrationStatusJsonParser)
  List<String> logTail
) {

  private static final String TRIGGER_SCHEDULE = "schedule";
  private static final String TRIGGER_REQUEST = "request";

  /// 실행 계기 > 표시 이름 (모르는 값은 그대로)
  public String triggerLabel() {
    if (TRIGGER_SCHEDULE.equals(trigger)) {
      return "정기 실행";
    }
    if (TRIGGER_REQUEST.equals(trigger)) {
      return "관리자 요청";
    }
    return trigger;
  }

  /// 오래됐는지 따질 기준 시각: 끝난 시각, 없으면(진행 중) 시작 시각
  public LocalDateTime lastActivityAt() {
    return finishedAt != null ? finishedAt : startedAt;
  }

  public boolean hasLogTail() {
    return logTail != null && !logTail.isEmpty();
  }
}
