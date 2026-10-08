package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.LogFileListResponse;
import com.chuseok22.elumserver.admin.application.dto.response.LogTailResponse;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class AdminLogService {

  private static final int DEFAULT_INITIAL_LINES = 200;
  private static final int MAX_INITIAL_LINES = 1000;
  // 한 번의 폴링 응답 상한. 밀린 로그가 이보다 많으면 뒤쪽(최신)을 우선한다.
  private static final long MAX_CHUNK_BYTES = 256 * 1024;

  private final LogFileLocator locator;

  public AdminLogService(LogFileLocator locator) {
    this.locator = locator;
  }

  /**
   * offset이 null이면 파일 끝에서 마지막 N줄을, 지정되면 그 바이트부터의 증분을 돌려준다.
   * 증분은 항상 개행 경계까지만 잘라 보내 멀티바이트 문자·줄이 중간에서 찢기지 않게 한다.
   * 파일이 롤링·축소돼 offset이 파일 크기보다 크면 첫 호출처럼 마지막 N줄로 리셋한다.
   * path가 없으면 지금 응답 중인 인스턴스의 elum.log 를 본다. 압축 파일은 이어 읽을 수 없어 검색으로 연다.
   */
  public LogTailResponse tail(String path, Long offset, Integer lines) {
    String target = path == null || path.isBlank() ? locator.currentLogPath() : path;
    if (target.endsWith(".gz")) {
      throw new CustomException(ErrorCode.INVALID_LOG_PATH);
    }
    Path logFile = locator.resolve(target);
    if (!Files.exists(logFile)) {
      return LogTailResponse.notFound();
    }
    try (RandomAccessFile file = new RandomAccessFile(logFile.toFile(), "r")) {
      long fileSize = file.length();
      if (offset == null || offset < 0 || offset > fileSize) {
        return new LogTailResponse(true, fileSize, readLastLines(file, fileSize, clampLines(lines)));
      }
      long start = Math.max(offset, fileSize - MAX_CHUNK_BYTES);
      byte[] buffer = readRange(file, start, fileSize);
      // 마지막 개행까지만 보낸다 — 쓰다 만 줄·찢긴 UTF-8 문자는 다음 폴링에서 완성돼 내려간다.
      int lastNewline = lastIndexOfNewline(buffer);
      if (lastNewline < 0) {
        return new LogTailResponse(true, start, "");
      }
      String content = new String(buffer, 0, lastNewline + 1, StandardCharsets.UTF_8);
      return new LogTailResponse(true, start + lastNewline + 1, content);
    } catch (IOException e) {
      log.warn("[관리자 로그] 로그 파일 읽기 실패: path={}", logFile, e);
      throw new CustomException(ErrorCode.LOG_FILE_READ_FAILED);
    }
  }

  public LogFileListResponse listFiles() {
    return locator.list();
  }

  public Path download(String path) {
    return locator.resolveExisting(path);
  }

  public void delete(String path) {
    Path file = locator.resolveExisting(path);
    if (!locator.isDeletable(path)) {
      throw new CustomException(ErrorCode.LOG_FILE_IN_USE);
    }
    try {
      Files.delete(file);
      log.info("[관리자 로그] 로그 파일 삭제: path={}", path);
    } catch (IOException e) {
      log.warn("[관리자 로그] 로그 파일 삭제 실패: path={}", path, e);
      throw new CustomException(ErrorCode.LOG_FILE_DELETE_FAILED);
    }
  }

  private int clampLines(Integer lines) {
    if (lines == null || lines <= 0) {
      return DEFAULT_INITIAL_LINES;
    }
    return Math.min(lines, MAX_INITIAL_LINES);
  }

  private String readLastLines(RandomAccessFile file, long fileSize, int lineCount) throws IOException {
    long chunk = Math.min(fileSize, MAX_CHUNK_BYTES);
    String text = new String(readRange(file, fileSize - chunk, fileSize), StandardCharsets.UTF_8);
    String[] split = text.split("\n", -1);
    // 파일이 개행으로 끝나면 split 마지막의 빈 요소는 줄이 아니므로 세지 않는다.
    int effectiveLines = text.endsWith("\n") ? split.length - 1 : split.length;
    if (effectiveLines <= lineCount) {
      // 청크가 파일 앞부분을 잘랐다면 첫 줄은 온전하지 않을 수 있으므로 버린다.
      return chunk < fileSize && split.length > 1
        ? String.join("\n", Arrays.copyOfRange(split, 1, split.length))
        : text;
    }
    int from = effectiveLines - lineCount;
    return String.join("\n", Arrays.copyOfRange(split, from, split.length));
  }

  private byte[] readRange(RandomAccessFile file, long start, long end) throws IOException {
    byte[] buffer = new byte[(int) (end - start)];
    file.seek(start);
    file.readFully(buffer);
    return buffer;
  }

  private int lastIndexOfNewline(byte[] buffer) {
    for (int i = buffer.length - 1; i >= 0; i--) {
      if (buffer[i] == '\n') {
        return i;
      }
    }
    return -1;
  }
}
