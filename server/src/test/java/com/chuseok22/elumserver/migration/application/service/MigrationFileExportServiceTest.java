package com.chuseok22.elumserver.migration.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.NoticeProperties;
import com.chuseok22.elumserver.common.infrastructure.properties.RoutineProperties;
import com.chuseok22.elumserver.common.infrastructure.properties.TalkProperties;
import com.chuseok22.elumserver.common.infrastructure.properties.TtsProperties;
import com.chuseok22.elumserver.migration.application.dto.response.MigrationFileListResponse;
import com.chuseok22.elumserver.migration.core.MigrationFileArea;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * 이전 파일 내보내기: 목록 해시, 꺼짐 404, 경로 이탈·링크 거부 (#1053)
 * 깨지면: 그림이 덜 옮겨지거나, 관리자 API 로 저장 폴더 밖 파일이 읽힌다
 */
class MigrationFileExportServiceTest {

  // "abc" 의 SHA-256
  private static final String SHA256_OF_ABC = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";

  @TempDir
  Path tempDir;

  private Path routineImagesRoot;
  private SystemConfigService systemConfigService;
  private MigrationFileExportService service;

  @BeforeEach
  void setUp() throws IOException {
    routineImagesRoot = Files.createDirectories(tempDir.resolve("routine-images"));
    systemConfigService = mock(SystemConfigService.class);
    when(systemConfigService.getBoolean(ConfigKey.MIGRATION_FILE_EXPORT_ENABLED)).thenReturn(true);
    service = new MigrationFileExportService(
      systemConfigService,
      new RoutineProperties(routineImagesRoot.toString()),
      new TalkProperties(tempDir.resolve("talk-images").toString(), null),
      new NoticeProperties(tempDir.resolve("notice-images").toString()),
      new TtsProperties(true, tempDir.resolve("routine-speech").toString())
    );
  }

  private Path writeRoutineImage(String relativePath, String content) throws IOException {
    Path file = routineImagesRoot.resolve(relativePath);
    Files.createDirectories(file.getParent());
    return Files.writeString(file, content, StandardCharsets.UTF_8);
  }

  @Test
  @DisplayName("목록은 상대 경로·크기·SHA-256 을 준다")
  void listFiles_returnsRelativePathSizeAndSha256() throws IOException {
    writeRoutineImage("batch-1/1.png", "abc");

    MigrationFileListResponse response = service.listFiles(MigrationFileArea.ROUTINE_IMAGES);

    assertThat(response.area()).isEqualTo("routine-images");
    assertThat(response.fileCount()).isEqualTo(1);
    assertThat(response.totalBytes()).isEqualTo(3);
    assertThat(response.files().get(0).path()).isEqualTo("batch-1/1.png");
    assertThat(response.files().get(0).size()).isEqualTo(3);
    assertThat(response.files().get(0).sha256()).isEqualTo(SHA256_OF_ABC);
  }

  @Test
  @DisplayName("목록은 심볼릭 링크를 뺀다 — 저장 폴더 밖 파일이 섞이지 않게")
  void listFiles_skipsSymbolicLinks() throws IOException {
    writeRoutineImage("batch-1/1.png", "abc");
    Path outside = Files.writeString(tempDir.resolve("secret.txt"), "secret");
    Files.createSymbolicLink(routineImagesRoot.resolve("link.png"), outside);

    assertThat(service.listFiles(MigrationFileArea.ROUTINE_IMAGES).fileCount()).isEqualTo(1);
  }

  @Test
  @DisplayName("기준 폴더가 아직 없으면 빈 목록")
  void listFiles_missingRoot_isEmpty() {
    assertThat(service.listFiles(MigrationFileArea.TALK_IMAGES).fileCount()).isZero();
  }

  @Test
  @DisplayName("설정이 꺼져 있으면 목록도 다운로드도 MIGRATION_FILE_EXPORT_DISABLED")
  void disabled_throwsExportDisabled() {
    when(systemConfigService.getBoolean(ConfigKey.MIGRATION_FILE_EXPORT_ENABLED)).thenReturn(false);

    assertThatThrownBy(() -> service.listFiles(MigrationFileArea.ROUTINE_IMAGES))
      .isInstanceOf(CustomException.class).extracting("errorCode").isEqualTo(ErrorCode.MIGRATION_FILE_EXPORT_DISABLED);
    assertThatThrownBy(() -> service.resolveForDownload(MigrationFileArea.ROUTINE_IMAGES, "batch-1/1.png"))
      .isInstanceOf(CustomException.class).extracting("errorCode").isEqualTo(ErrorCode.MIGRATION_FILE_EXPORT_DISABLED);
  }

  @Test
  @DisplayName("다운로드: ../ 로 폴더 밖을 가리키면 거부")
  void download_rejectsParentTraversal() throws IOException {
    Files.writeString(tempDir.resolve("secret.txt"), "secret");

    assertThatThrownBy(() -> service.resolveForDownload(MigrationFileArea.ROUTINE_IMAGES, "../secret.txt"))
      .isInstanceOf(CustomException.class).extracting("errorCode").isEqualTo(ErrorCode.INVALID_MIGRATION_FILE_PATH);
  }

  @Test
  @DisplayName("다운로드: 절대 경로 거부")
  void download_rejectsAbsolutePath() {
    assertThatThrownBy(() -> service.resolveForDownload(MigrationFileArea.ROUTINE_IMAGES, "/etc/passwd"))
      .isInstanceOf(CustomException.class).extracting("errorCode").isEqualTo(ErrorCode.INVALID_MIGRATION_FILE_PATH);
  }

  @Test
  @DisplayName("다운로드: 심볼릭 링크 파일·폴더 거부")
  void download_rejectsSymbolicLink() throws IOException {
    Path outsideDir = Files.createDirectories(tempDir.resolve("outside"));
    Files.writeString(outsideDir.resolve("secret.txt"), "secret");
    Files.createSymbolicLink(routineImagesRoot.resolve("link.txt"), outsideDir.resolve("secret.txt"));
    Files.createSymbolicLink(routineImagesRoot.resolve("linked-dir"), outsideDir);

    assertThatThrownBy(() -> service.resolveForDownload(MigrationFileArea.ROUTINE_IMAGES, "link.txt"))
      .isInstanceOf(CustomException.class).extracting("errorCode").isEqualTo(ErrorCode.INVALID_MIGRATION_FILE_PATH);
    assertThatThrownBy(() -> service.resolveForDownload(MigrationFileArea.ROUTINE_IMAGES, "linked-dir/secret.txt"))
      .isInstanceOf(CustomException.class).extracting("errorCode").isEqualTo(ErrorCode.INVALID_MIGRATION_FILE_PATH);
  }

  @Test
  @DisplayName("다운로드: 없는 파일은 MIGRATION_FILE_NOT_FOUND")
  void download_missing_throwsNotFound() {
    assertThatThrownBy(() -> service.resolveForDownload(MigrationFileArea.ROUTINE_IMAGES, "batch-9/1.png"))
      .isInstanceOf(CustomException.class).extracting("errorCode").isEqualTo(ErrorCode.MIGRATION_FILE_NOT_FOUND);
  }

  @Test
  @DisplayName("다운로드: 저장 폴더 안 일반 파일은 그 경로를 준다")
  void download_valid_returnsFile() throws IOException {
    Path file = writeRoutineImage("batch-1/1.png", "abc");

    assertThat(service.resolveForDownload(MigrationFileArea.ROUTINE_IMAGES, "batch-1/1.png")).isEqualTo(file.toAbsolutePath().normalize());
  }

  @Test
  @DisplayName("모르는 종류 코드는 INVALID_MIGRATION_FILE_AREA")
  void fromCode_unknown_throwsInvalidArea() {
    assertThatThrownBy(() -> MigrationFileArea.fromCode("logs"))
      .isInstanceOf(CustomException.class).extracting("errorCode").isEqualTo(ErrorCode.INVALID_MIGRATION_FILE_AREA);
  }
}
