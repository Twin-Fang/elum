package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.dto.request.LoggerLevelRequest;
import com.chuseok22.elumserver.admin.application.dto.response.DeployHistoryResponse;
import com.chuseok22.elumserver.admin.application.dto.response.LogFileListResponse;
import com.chuseok22.elumserver.admin.application.dto.response.LogInstanceResponse;
import com.chuseok22.elumserver.admin.application.dto.response.LogSearchResponse;
import com.chuseok22.elumserver.admin.application.dto.response.LogTailResponse;
import com.chuseok22.elumserver.admin.application.dto.response.LoggerLevelResponse;
import com.chuseok22.elumserver.admin.application.dto.response.RecentErrorsResponse;
import com.chuseok22.elumserver.admin.application.service.AdminLogLevelService;
import com.chuseok22.elumserver.admin.application.service.AdminLogOverviewService;
import com.chuseok22.elumserver.admin.application.service.AdminLogSearchService;
import com.chuseok22.elumserver.admin.application.service.AdminLogService;
import com.chuseok22.elumserver.admin.application.service.DeployHistoryService;
import com.chuseok22.elumserver.common.application.exception.JsonErrorResponse;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import java.io.FilterInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

// 화면 스크립트가 fetch 로 부르므로 JSON 에러가 필요하다(@JsonErrorResponse).
// @LogMonitoring 은 일부러 붙이지 않는다: 2초 폴링·로그 조회가 그대로 로그 파일에 쌓여 로그를 로그가 덮는다.
@Slf4j
@RestController
@JsonErrorResponse
@RequiredArgsConstructor
public class AdminLogApiController {

  private final AdminLogService adminLogService;
  private final AdminLogSearchService adminLogSearchService;
  private final DeployHistoryService deployHistoryService;
  private final AdminLogLevelService adminLogLevelService;
  private final AdminLogOverviewService adminLogOverviewService;

  @GetMapping("/admin/logs/api/instance")
  public LogInstanceResponse instance() {
    return adminLogOverviewService.instance();
  }

  @GetMapping("/admin/logs/api/tail")
  public LogTailResponse tail(
    @RequestParam(required = false) String path,
    @RequestParam(required = false) Long offset,
    @RequestParam(required = false) Integer lines
  ) {
    return adminLogService.tail(path, offset, lines);
  }

  @GetMapping("/admin/logs/api/files")
  public LogFileListResponse files() {
    return adminLogService.listFiles();
  }

  @DeleteMapping("/admin/logs/api/files")
  public ResponseEntity<Void> delete(@RequestParam String path) {
    adminLogService.delete(path);
    return ResponseEntity.noContent().build();
  }

  /**
   * 파일째 내려받는다. 기록 중인 파일은 받는 사이에도 자라므로, 요청 시점 크기만큼만 보낸다 —
   * Content-Length 와 실제 바이트가 어긋나면 브라우저가 다운로드를 실패로 처리한다.
   */
  @GetMapping("/admin/logs/api/download")
  public ResponseEntity<InputStreamResource> download(@RequestParam String path) {
    Path file = adminLogService.download(path);
    try {
      long size = Files.size(file);
      InputStream body = new BoundedInputStream(Files.newInputStream(file), size);
      MediaType type = path.endsWith(".gz")
        ? MediaType.parseMediaType("application/gzip")
        : new MediaType(MediaType.TEXT_PLAIN, StandardCharsets.UTF_8);
      return ResponseEntity.ok()
        .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.attachment()
          .filename(path.replace('/', '_'), StandardCharsets.UTF_8).build().toString())
        .contentType(type)
        .contentLength(size)
        .body(new InputStreamResource(body));
    } catch (IOException e) {
      log.warn("[관리자 로그] 다운로드 준비 실패: path={}", path, e);
      throw new CustomException(ErrorCode.LOG_FILE_READ_FAILED);
    }
  }

  @GetMapping("/admin/logs/api/search")
  public LogSearchResponse search(
    @RequestParam(required = false) String path,
    @RequestParam(required = false) String level,
    @RequestParam(required = false) String q,
    @RequestParam(required = false) String from,
    @RequestParam(required = false) Integer limit
  ) {
    return adminLogSearchService.search(path, level, q, from, limit);
  }

  @GetMapping("/admin/logs/api/deploys")
  public DeployHistoryResponse deploys() {
    return deployHistoryService.list(Instant.now());
  }

  @GetMapping("/admin/logs/api/levels")
  public List<LoggerLevelResponse> levels() {
    return adminLogLevelService.list();
  }

  @PutMapping("/admin/logs/api/levels")
  public LoggerLevelResponse changeLevel(@RequestBody LoggerLevelRequest request) {
    return adminLogLevelService.change(request.logger(), request.level());
  }

  @GetMapping("/admin/logs/api/errors")
  public RecentErrorsResponse errors() {
    return adminLogOverviewService.recentErrors(Instant.now());
  }

  private static final class BoundedInputStream extends FilterInputStream {

    private long remaining;

    BoundedInputStream(InputStream in, long limit) {
      super(in);
      this.remaining = limit;
    }

    @Override
    public int read() throws IOException {
      if (remaining <= 0) {
        return -1;
      }
      int b = super.read();
      if (b >= 0) {
        remaining--;
      }
      return b;
    }

    @Override
    public int read(byte[] buffer, int off, int len) throws IOException {
      if (remaining <= 0) {
        return -1;
      }
      int n = super.read(buffer, off, (int) Math.min(len, remaining));
      if (n > 0) {
        remaining -= n;
      }
      return n;
    }
  }
}
