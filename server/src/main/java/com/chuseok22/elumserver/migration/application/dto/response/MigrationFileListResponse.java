package com.chuseok22.elumserver.migration.application.dto.response;

import java.util.List;

/**
 * 이전 파일 목록: 종류 코드, 개수, 전체 바이트, 파일별 상대 경로·크기·SHA-256·수정 시각
 */
public record MigrationFileListResponse(
  String area,
  int fileCount,
  long totalBytes,
  List<MigrationFileEntry> files
) {

  /// 경로는 기준 폴더 기준 상대 경로(/ 구분), 수정 시각은 ISO-8601
  public record MigrationFileEntry(String path, long size, String sha256, String modifiedAt) {
  }
}
