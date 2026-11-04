package com.chuseok22.elumserver.migration.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.NoticeProperties;
import com.chuseok22.elumserver.common.infrastructure.properties.RoutineProperties;
import com.chuseok22.elumserver.common.infrastructure.properties.TalkProperties;
import com.chuseok22.elumserver.common.infrastructure.properties.TtsProperties;
import com.chuseok22.elumserver.migration.application.dto.response.MigrationFileListResponse;
import com.chuseok22.elumserver.migration.application.dto.response.MigrationFileListResponse.MigrationFileEntry;
import com.chuseok22.elumserver.migration.core.MigrationFileArea;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.InvalidPathException;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.security.DigestInputStream;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.List;
import java.util.stream.Stream;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * 서버 이전 파일 내보내기 (#1053): 설정 확인, 종류별 파일 목록·해시, 다운로드 경로 검사
 * 읽기 전용. 파일을 바꾸거나 지우지 않는다
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MigrationFileExportService {

  private static final String DIGEST_ALGORITHM = "SHA-256";
  private static final String PATH_SEPARATOR = "/";

  private final SystemConfigService systemConfigService;
  private final RoutineProperties routineProperties;
  private final TalkProperties talkProperties;
  private final NoticeProperties noticeProperties;
  private final TtsProperties ttsProperties;

  /**
   * 종류별 파일 목록: 설정 확인 > 일반 파일만(심볼릭 링크 제외) > 경로 순 정렬 > 크기·SHA-256
   * 기준 폴더가 아직 없으면 빈 목록
   */
  public MigrationFileListResponse listFiles(MigrationFileArea area) {
    requireExportEnabled();
    Path root = baseDirectory(area);
    if (!Files.isDirectory(root, LinkOption.NOFOLLOW_LINKS)) {
      return new MigrationFileListResponse(area.getCode(), 0, 0, List.of());
    }
    try (Stream<Path> paths = Files.walk(root)) {
      List<MigrationFileEntry> files = paths
        .filter(path -> Files.isRegularFile(path, LinkOption.NOFOLLOW_LINKS))
        .filter(path -> !hasSymbolicLinkBetween(root, path))
        .sorted()
        .map(path -> toEntry(root, path))
        .toList();
      long totalBytes = files.stream().mapToLong(MigrationFileEntry::size).sum();
      return new MigrationFileListResponse(area.getCode(), files.size(), totalBytes, files);
    } catch (IOException | UncheckedIOException e) {
      log.warn("[migration export] list failed : area={}", area.getCode(), e);
      throw new CustomException(ErrorCode.MIGRATION_FILE_READ_FAILED);
    }
  }

  /**
   * 다운로드 경로 검사: 설정 확인 > 정규화 > 기준 폴더 안 > 경로 중 심볼릭 링크 없음 > 일반 파일
   */
  public Path resolveForDownload(MigrationFileArea area, String relativePath) {
    requireExportEnabled();
    Path root = baseDirectory(area);
    Path resolved = resolveInside(root, relativePath);
    if (hasSymbolicLinkBetween(root, resolved)) {
      throw new CustomException(ErrorCode.INVALID_MIGRATION_FILE_PATH);
    }
    if (!Files.isRegularFile(resolved, LinkOption.NOFOLLOW_LINKS)) {
      throw new CustomException(ErrorCode.MIGRATION_FILE_NOT_FOUND);
    }
    return resolved;
  }

  private void requireExportEnabled() {
    if (!systemConfigService.getBoolean(ConfigKey.MIGRATION_FILE_EXPORT_ENABLED)) {
      throw new CustomException(ErrorCode.MIGRATION_FILE_EXPORT_DISABLED);
    }
  }

  /// 종류 > 기준 폴더 (각 저장소 설정값, 컨테이너 /app 기준 상대 경로)
  private Path baseDirectory(MigrationFileArea area) {
    String storagePath = switch (area) {
      case ROUTINE_IMAGES -> routineProperties.imageStoragePath();
      case TALK_IMAGES -> talkProperties.imageStoragePath();
      case NOTICE_IMAGES -> noticeProperties.imageStoragePath();
      case ROUTINE_SPEECH -> ttsProperties.speechStoragePath();
    };
    return Path.of(storagePath).toAbsolutePath().normalize();
  }

  /// 상대 경로 > 기준 폴더 안 실제 경로 (빈 값·절대 경로·폴더 밖·기준 폴더 자체·잘못된 글자는 거부)
  private static Path resolveInside(Path root, String relativePath) {
    if (relativePath == null || relativePath.isBlank()) {
      throw new CustomException(ErrorCode.INVALID_MIGRATION_FILE_PATH);
    }
    try {
      if (Path.of(relativePath).isAbsolute()) {
        throw new CustomException(ErrorCode.INVALID_MIGRATION_FILE_PATH);
      }
      Path resolved = root.resolve(relativePath).normalize();
      if (!resolved.startsWith(root) || resolved.equals(root)) {
        throw new CustomException(ErrorCode.INVALID_MIGRATION_FILE_PATH);
      }
      return resolved;
    } catch (InvalidPathException e) {
      throw new CustomException(ErrorCode.INVALID_MIGRATION_FILE_PATH);
    }
  }

  /// 기준 폴더 아래 경로 조각 중 심볼릭 링크가 있는가 (파일 자신 포함, 기준 폴더 밖을 가리킬 수 있음)
  private static boolean hasSymbolicLinkBetween(Path root, Path target) {
    Path current = root;
    for (Path part : root.relativize(target)) {
      current = current.resolve(part);
      if (Files.isSymbolicLink(current)) {
        return true;
      }
    }
    return false;
  }

  private static MigrationFileEntry toEntry(Path root, Path file) {
    try {
      String relativePath = root.relativize(file).toString().replace(file.getFileSystem().getSeparator(), PATH_SEPARATOR);
      return new MigrationFileEntry(
        relativePath,
        Files.size(file),
        sha256Of(file),
        Files.getLastModifiedTime(file, LinkOption.NOFOLLOW_LINKS).toInstant().toString()
      );
    } catch (IOException e) {
      throw new UncheckedIOException(e);
    }
  }

  /// 파일 내용 > SHA-256 소문자 16진수 (내용은 버리고 해시만)
  private static String sha256Of(Path file) throws IOException {
    MessageDigest digest = newDigest();
    try (InputStream input = new DigestInputStream(Files.newInputStream(file), digest)) {
      input.transferTo(OutputStream.nullOutputStream());
    }
    return HexFormat.of().formatHex(digest.digest());
  }

  private static MessageDigest newDigest() {
    try {
      return MessageDigest.getInstance(DIGEST_ALGORITHM);
    } catch (NoSuchAlgorithmException e) {
      throw new IllegalStateException(DIGEST_ALGORITHM + " not available", e);
    }
  }
}
