package com.chuseok22.elumserver.migration.application.controller;

import com.chuseok22.elumserver.admin.application.service.AdminAuditService;
import com.chuseok22.elumserver.admin.core.AdminAuditAction;
import com.chuseok22.elumserver.common.application.exception.JsonErrorResponse;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.migration.application.dto.response.MigrationFileListResponse;
import com.chuseok22.elumserver.migration.application.service.MigrationFileExportService;
import com.chuseok22.elumserver.migration.core.MigrationFileArea;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.FileSystemResource;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 서버 이전 파일 내보내기 관리자 API (#1053, 임시: 이전이 끝나면 제거)
 * 시스템 설정 "이전 파일 내보내기"가 꺼져 있으면 404. 받는 쪽은 server/tool/nas-mirror/pull-files.sh
 */
// 스크립트가 부르므로 JSON 에러. @LogMonitoring 은 붙이지 않음 (파일 수백 개 다운로드가 로그를 덮음)
@Slf4j
@RestController
@JsonErrorResponse
@RequiredArgsConstructor
public class AdminMigrationFileApiController {

  private final MigrationFileExportService migrationFileExportService;
  private final AdminAuditService adminAuditService;

  /// 종류별 파일 목록 (조회마다 관리자 기록 1건: 대상 = 종류 코드, 개수·바이트)
  @GetMapping("/admin/migration/api/files")
  public MigrationFileListResponse files(@RequestParam String area) {
    MigrationFileListResponse response = migrationFileExportService.listFiles(MigrationFileArea.fromCode(area));
    adminAuditService.record(
      AdminAuditAction.MIGRATION_FILES_LISTED,
      response.area(),
      "files=" + response.fileCount() + " bytes=" + response.totalBytes()
    );
    return response;
  }

  /// 파일 그대로 내려받기 (관리자 기록 없음, 애플리케이션 로그만)
  @GetMapping("/admin/migration/api/files/download")
  public ResponseEntity<FileSystemResource> download(@RequestParam String area, @RequestParam String path) {
    MigrationFileArea fileArea = MigrationFileArea.fromCode(area);
    Path file = migrationFileExportService.resolveForDownload(fileArea, path);
    try {
      long size = Files.size(file);
      log.debug("[migration export] download : area={} size={}", fileArea.getCode(), size);
      return ResponseEntity.ok()
        .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.attachment()
          .filename(file.getFileName().toString(), StandardCharsets.UTF_8).build().toString())
        .contentType(MediaType.APPLICATION_OCTET_STREAM)
        .contentLength(size)
        .body(new FileSystemResource(file));
    } catch (IOException e) {
      log.warn("[migration export] download failed : area={}", fileArea.getCode(), e);
      throw new CustomException(ErrorCode.MIGRATION_FILE_READ_FAILED);
    }
  }
}
