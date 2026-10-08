package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.chuseok22.elumserver.admin.application.dto.response.LogTailResponse;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class AdminLogServiceTest {

  @TempDir
  Path tempDir;

  private AdminLogService service;
  private Path logFile;

  @BeforeEach
  void setUp() throws IOException {
    service = new AdminLogService(new LogFileLocator(tempDir.toString(), "green"));
    Files.createDirectories(tempDir.resolve("green"));
    logFile = tempDir.resolve("green/elum.log");
  }

  @Test
  @DisplayName("로그 파일이 없으면 exists=false를 반환하고 예외를 던지지 않는다")
  void tail_missingFile_returnsNotFound() {
    LogTailResponse response = service.tail(null, null, null);

    assertThat(response.exists()).isFalse();
    assertThat(response.nextOffset()).isZero();
    assertThat(response.content()).isEmpty();
  }

  @Test
  @DisplayName("첫 호출(offset 없음)은 마지막 N줄만 반환한다")
  void tail_firstCall_returnsLastLines() throws IOException {
    Files.writeString(logFile, "line1\nline2\nline3\nline4\n", StandardCharsets.UTF_8);

    LogTailResponse response = service.tail(null, null, 2);

    assertThat(response.exists()).isTrue();
    assertThat(response.content()).isEqualTo("line3\nline4\n");
    assertThat(response.nextOffset()).isEqualTo(Files.size(logFile));
  }

  @Test
  @DisplayName("offset 이후에 추가된 내용만 증분으로 반환한다")
  void tail_withOffset_returnsIncrement() throws IOException {
    Files.writeString(logFile, "old1\nold2\n", StandardCharsets.UTF_8);
    long offset = service.tail(null, null, null).nextOffset();

    Files.writeString(logFile, "새로운 로그\n", StandardCharsets.UTF_8, StandardOpenOption.APPEND);
    LogTailResponse response = service.tail(null, offset, null);

    assertThat(response.content()).isEqualTo("새로운 로그\n");
    assertThat(response.nextOffset()).isEqualTo(Files.size(logFile));
  }

  @Test
  @DisplayName("추가된 내용이 없으면 빈 증분을 반환한다")
  void tail_noNewContent_returnsEmpty() throws IOException {
    Files.writeString(logFile, "line1\n", StandardCharsets.UTF_8);
    long offset = service.tail(null, null, null).nextOffset();

    LogTailResponse response = service.tail(null, offset, null);

    assertThat(response.content()).isEmpty();
    assertThat(response.nextOffset()).isEqualTo(offset);
  }

  @Test
  @DisplayName("증분은 개행 경계까지만 반환하고, 쓰다 만 줄은 다음 폴링으로 미룬다")
  void tail_partialLine_deferredUntilNewline() throws IOException {
    Files.writeString(logFile, "done\n", StandardCharsets.UTF_8);
    long offset = service.tail(null, null, null).nextOffset();

    Files.writeString(logFile, "writing...", StandardCharsets.UTF_8, StandardOpenOption.APPEND);
    LogTailResponse partial = service.tail(null, offset, null);

    assertThat(partial.content()).isEmpty();
    assertThat(partial.nextOffset()).isEqualTo(offset);

    Files.writeString(logFile, "완료\n", StandardCharsets.UTF_8, StandardOpenOption.APPEND);
    LogTailResponse completed = service.tail(null, partial.nextOffset(), null);

    assertThat(completed.content()).isEqualTo("writing...완료\n");
    assertThat(completed.nextOffset()).isEqualTo(Files.size(logFile));
  }

  @Test
  @DisplayName("파일이 롤링돼 offset이 파일 크기보다 크면 마지막 N줄로 리셋한다")
  void tail_offsetBeyondFileSize_resetsToLastLines() throws IOException {
    Files.writeString(logFile, "rolled1\nrolled2\n", StandardCharsets.UTF_8);

    LogTailResponse response = service.tail(null, 999_999L, 1);

    assertThat(response.content()).isEqualTo("rolled2\n");
    assertThat(response.nextOffset()).isEqualTo(Files.size(logFile));
  }

  @Test
  @DisplayName("요청 줄 수가 상한(1000)을 넘으면 상한으로 잘라 반환한다")
  void tail_lineCountClamped() throws IOException {
    StringBuilder sb = new StringBuilder();
    for (int i = 1; i <= 1500; i++) {
      sb.append("line").append(i).append('\n');
    }
    Files.writeString(logFile, sb.toString(), StandardCharsets.UTF_8);

    LogTailResponse response = service.tail(null, null, 5000);

    assertThat(response.content().lines().count()).isEqualTo(1000);
    assertThat(response.content()).startsWith("line501\n").endsWith("line1500\n");
  }

  @Test
  @DisplayName("다른 파일 경로를 주면 그 파일을 tail 하고, 압축 파일은 거부한다")
  void tail_otherPath() throws IOException {
    Files.createDirectories(tempDir.resolve("blue"));
    Files.writeString(tempDir.resolve("blue/elum-error.log"), "blue error\n", StandardCharsets.UTF_8);

    assertThat(service.tail("blue/elum-error.log", null, null).content()).isEqualTo("blue error\n");
    assertThatThrownBy(() -> service.tail("blue/elum.2026-10-07.0.log.gz", null, null))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(ErrorCode.INVALID_LOG_PATH);
  }

  @Test
  @DisplayName("지금 기록 중인 파일은 색과 무관하게 지울 수 없고, 롤링된 파일은 지운다")
  void delete_activeFilesProtected() throws IOException {
    Files.createDirectories(tempDir.resolve("blue"));
    Files.writeString(logFile, "x\n", StandardCharsets.UTF_8);
    Files.writeString(tempDir.resolve("blue/elum.log"), "x\n", StandardCharsets.UTF_8);
    Path rolled = tempDir.resolve("blue/elum.2026-10-07.0.log.gz");
    Files.write(rolled, new byte[] {1, 2, 3});

    assertThatThrownBy(() -> service.delete("green/elum.log"))
      .extracting("errorCode").isEqualTo(ErrorCode.LOG_FILE_IN_USE);
    assertThatThrownBy(() -> service.delete("blue/elum.log"))
      .extracting("errorCode").isEqualTo(ErrorCode.LOG_FILE_IN_USE);

    service.delete("blue/elum.2026-10-07.0.log.gz");
    assertThat(rolled).doesNotExist();
  }

  @Test
  @DisplayName("없는 파일을 지우거나 받으려 하면 LOG_FILE_NOT_FOUND")
  void missingFile() {
    assertThatThrownBy(() -> service.delete("blue/elum.2026-10-01.0.log.gz"))
      .extracting("errorCode").isEqualTo(ErrorCode.LOG_FILE_NOT_FOUND);
    assertThatThrownBy(() -> service.download("green/elum.log"))
      .extracting("errorCode").isEqualTo(ErrorCode.LOG_FILE_NOT_FOUND);
  }
}
