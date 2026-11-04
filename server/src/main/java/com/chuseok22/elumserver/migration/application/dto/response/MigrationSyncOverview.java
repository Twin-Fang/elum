package com.chuseok22.elumserver.migration.application.dto.response;

import com.chuseok22.elumserver.migration.core.MigrationSyncReport;
import com.chuseok22.elumserver.migration.core.MigrationVerifyReport;

/**
 * 서버 이전 동기화·검사 상태 한 화면분 (#1062)
 * 폴더가 없는 서버(옛 서버)는 isSyncDirectoryPresent=false, 나머지 칸은 비움
 */
public record MigrationSyncOverview(
  boolean isSyncDirectoryPresent,
  MigrationStatusFileView<MigrationSyncReport> syncStatus,
  MigrationStatusFileView<MigrationVerifyReport> verifyStatus,
  boolean isPaused,
  // 멈춤 표식 내용 한 줄 ("{ISO 시각} {관리자 이름}"), 없으면 null
  String pausedNote,
  boolean isSyncRequested,
  boolean isVerifyRequested,
  // 마지막 동기화가 staleThresholdMinutes(분)보다 오래됨
  boolean isSyncStale,
  long staleThresholdMinutes
) {

  /// 동기화 폴더가 없는 서버
  public static MigrationSyncOverview withoutSyncDirectory(long staleThresholdMinutes) {
    return new MigrationSyncOverview(false, MigrationStatusFileView.missing(), MigrationStatusFileView.missing(),
      false, null, false, false, false, staleThresholdMinutes);
  }
}
