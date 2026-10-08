package com.chuseok22.elumserver.admin.application.dto.response;

import java.time.Instant;
import java.util.List;

public record LogFileListResponse(
  String instance,
  long totalBytes,
  List<Group> groups
) {

  public record Group(
    String key,
    String label,
    long totalBytes,
    List<FileItem> files
  ) {

  }

  /**
   * @param path      API 에 그대로 넘기는 상대 경로 (예: green/elum.log)
   * @param active    지금 기록 중일 수 있는 파일 — 삭제 불가
   * @param deletable 화면의 삭제 버튼 노출 여부
   */
  public record FileItem(
    String path,
    String name,
    long size,
    Instant lastModified,
    boolean compressed,
    boolean active,
    boolean deletable
  ) {

  }
}
