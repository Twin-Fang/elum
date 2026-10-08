package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.chuseok22.elumserver.admin.application.dto.response.LogFileListResponse;
import com.chuseok22.elumserver.admin.application.dto.response.LogFileListResponse.Group;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.attribute.FileTime;
import java.time.Instant;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

class LogFileLocatorTest {

  @TempDir
  Path tempDir;

  private LogFileLocator locator;

  @BeforeEach
  void setUp() {
    locator = new LogFileLocator(tempDir.toString(), "green");
  }

  @ParameterizedTest
  @ValueSource(strings = {
    "../elum.log",
    "green/../../etc/passwd",
    "/etc/passwd",
    "green/elum.log/../../x.log",
    "green%2Felum.log",
    "green\\elum.log",
    "green/application.yml",
    "purple/elum.log",
    "elum.log",
    "green/elum.log.zip",
    ""
  })
  @DisplayName("정해진 모양이 아닌 경로는 모두 INVALID_LOG_PATH")
  void rejectsUnknownShapes(String path) {
    assertThatThrownBy(() -> locator.resolve(path))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(ErrorCode.INVALID_LOG_PATH);
  }

  @Test
  @DisplayName("null 경로도 INVALID_LOG_PATH")
  void rejectsNull() {
    assertThatThrownBy(() -> locator.resolve(null))
      .extracting("errorCode").isEqualTo(ErrorCode.INVALID_LOG_PATH);
  }

  @ParameterizedTest
  @ValueSource(strings = {
    "green/elum.log",
    "blue/elum-error.log",
    "local/elum.2026-10-08.3.log.gz",
    "blue/elum-error.2026-10-08.0.log.gz",
    "elum-server.log",
    "elum-server.2026-09-29.0.log.gz",
    "deploy-history.log"
  })
  @DisplayName("정해진 모양은 로그 폴더 안의 경로로 바뀐다")
  void acceptsKnownShapes(String path) {
    assertThat(locator.resolve(path).startsWith(locator.root())).isTrue();
  }

  @Test
  @DisplayName("인스턴스 폴더가 심볼릭 링크면 거부한다")
  void rejectsSymlinkedFolder() throws IOException {
    Path outside = Files.createDirectories(tempDir.resolve("outside"));
    Files.writeString(outside.resolve("elum.log"), "secret");
    Files.createSymbolicLink(tempDir.resolve("blue"), outside);

    assertThatThrownBy(() -> locator.resolve("blue/elum.log"))
      .extracting("errorCode").isEqualTo(ErrorCode.INVALID_LOG_PATH);
  }

  @Test
  @DisplayName("롤링된 파일과 이전 형식만 지울 수 있다")
  void deletable() {
    assertThat(locator.isDeletable("green/elum.log")).isFalse();
    assertThat(locator.isDeletable("blue/elum-error.log")).isFalse();
    assertThat(locator.isDeletable("deploy-history.log")).isFalse();
    assertThat(locator.isDeletable("blue/elum.2026-10-08.0.log.gz")).isTrue();
    assertThat(locator.isDeletable("elum-server.log")).isTrue();
    assertThat(locator.isDeletable("elum-server.2026-09-29.0.log.gz")).isTrue();
  }

  @Test
  @DisplayName("목록은 내 색 → 반대 색 → 이전 형식 → 배포 이력 순, 최신 파일이 위, 모르는 파일은 뺀다")
  void listsGroups() throws IOException {
    Files.createDirectories(tempDir.resolve("green"));
    Files.createDirectories(tempDir.resolve("blue"));
    write("green/elum.log", 10, "2026-10-08T03:00:00Z");
    write("green/elum.2026-10-07.0.log.gz", 5, "2026-10-07T03:00:00Z");
    write("green/notes.txt", 100, "2026-10-08T03:00:00Z");
    write("blue/elum.log", 7, "2026-10-07T09:00:00Z");
    write("elum-server.log", 3, "2026-10-01T00:00:00Z");
    write("deploy-history.log", 2, "2026-10-08T03:00:00Z");

    LogFileListResponse list = locator.list();

    assertThat(list.groups()).extracting(Group::key).containsExactly("green", "blue", "legacy", "history");
    Group green = list.groups().get(0);
    assertThat(green.files()).extracting("path").containsExactly("green/elum.log", "green/elum.2026-10-07.0.log.gz");
    assertThat(green.files().get(0).active()).isTrue();
    assertThat(green.files().get(1).deletable()).isTrue();
    assertThat(green.totalBytes()).isEqualTo(15);
    assertThat(list.totalBytes()).isEqualTo(27);
  }

  @Test
  @DisplayName("폴더가 없으면 빈 그룹으로 보여준다")
  void emptyWhenNoFolder() {
    LogFileListResponse list = locator.list();

    assertThat(list.groups()).extracting(Group::key).containsExactly("green", "blue");
    assertThat(list.totalBytes()).isZero();
  }

  private void write(String relative, int bytes, String modified) throws IOException {
    Path file = tempDir.resolve(relative);
    Files.write(file, new byte[bytes]);
    Files.setLastModifiedTime(file, FileTime.from(Instant.parse(modified)));
  }
}
