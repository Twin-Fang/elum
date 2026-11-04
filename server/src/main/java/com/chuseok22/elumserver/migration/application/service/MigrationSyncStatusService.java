package com.chuseok22.elumserver.migration.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorMessages;
import com.chuseok22.elumserver.common.infrastructure.properties.MigrationProperties;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.migration.application.dto.response.MigrationStatusFileView;
import com.chuseok22.elumserver.migration.application.dto.response.MigrationSyncOverview;
import com.chuseok22.elumserver.migration.application.service.MigrationStatusJsonParser.MalformedStatusException;
import com.chuseok22.elumserver.migration.core.MigrationControlFile;
import com.chuseok22.elumserver.migration.core.MigrationSyncReport;
import com.chuseok22.elumserver.migration.core.MigrationVerifyReport;
import java.io.BufferedReader;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/**
 * 서버 이전 동기화 상태 (#1062): NAS 결과 JSON 읽기, 요청·멈춤 표식 파일 만들기·지우기
 * 동기화·검사 실행은 NAS 스크립트가 함. 이 서버는 폴더 안 5개 파일만 다룸 (DB·명령 실행 없음)
 */
@Slf4j
@Service
public class MigrationSyncStatusService {

  // NAS 스크립트가 남기는 결과 파일 이름 (스크립트와 맞춘 이름)
  static final String SYNC_STATUS_FILE_NAME = "sync-status.json";
  static final String VERIFY_STATUS_FILE_NAME = "verify-status.json";
  // 마지막 동기화가 이보다 오래되면 경고 (분, 정기 실행 30분 간격의 2배)
  static final long SYNC_STALE_THRESHOLD_MINUTES = 60;
  // 결과 파일 최대 크기 (1MB, 넘으면 깨진 것으로 봄)
  private static final long MAX_STATUS_FILE_BYTES = 1_048_576;
  // 표식 내용 한 줄 최대 길이 (자)
  private static final int MAX_CONTROL_NOTE_LENGTH = 200;
  // 표식 내용의 관리자 이름이 없을 때
  private static final String UNKNOWN_ADMIN_NAME = "unknown";
  // 관리자 이름 속 공백·제어문자 > _ (한 줄 "{시각} {이름}" 형식 유지)
  private static final String NON_NAME_CHARACTERS = "[\\s\\p{Cntrl}]+";

  private final Path syncDirectory;
  private final Clock clock;

  // 생성자가 둘이라 스프링이 쓸 것을 명시 (빠뜨리면 서버가 뜨지 않음)
  @Autowired
  public MigrationSyncStatusService(MigrationProperties migrationProperties) {
    this(Path.of(migrationProperties.syncDir()), Clock.systemDefaultZone());
  }

  MigrationSyncStatusService(Path syncDirectory, Clock clock) {
    this.syncDirectory = syncDirectory.toAbsolutePath().normalize();
    this.clock = clock;
  }

  /**
   * 화면 상태 한 번에: 폴더 확인 > 결과 JSON 2개 > 표식 3개 > 오래됨 판정
   * 예외를 던지지 않음 (읽기 실패는 칸별 "읽을 수 없어요" 상태)
   */
  public MigrationSyncOverview readOverview() {
    if (!isSyncDirectoryPresent()) {
      return MigrationSyncOverview.withoutSyncDirectory(SYNC_STALE_THRESHOLD_MINUTES);
    }
    ZoneId zone = clock.getZone();
    MigrationStatusFileView<MigrationSyncReport> syncStatus = readStatusFile(SYNC_STATUS_FILE_NAME,
      json -> MigrationStatusJsonParser.parseSyncStatus(json, zone));
    MigrationStatusFileView<MigrationVerifyReport> verifyStatus = readStatusFile(VERIFY_STATUS_FILE_NAME,
      json -> MigrationStatusJsonParser.parseVerifyStatus(json, zone));
    boolean isPaused = hasControlFile(MigrationControlFile.SYNC_PAUSED);
    return new MigrationSyncOverview(
      true,
      syncStatus,
      verifyStatus,
      isPaused,
      isPaused ? readControlNote(MigrationControlFile.SYNC_PAUSED) : null,
      hasControlFile(MigrationControlFile.SYNC_REQUESTED),
      hasControlFile(MigrationControlFile.VERIFY_REQUESTED),
      isSyncStale(syncStatus),
      SYNC_STALE_THRESHOLD_MINUTES
    );
  }

  /// 지금 동기화 요청 표식 (NAS 1분 작업이 보고 실행 후 지움)
  public void requestSync(String adminName) {
    writeControlFile(MigrationControlFile.SYNC_REQUESTED, adminName);
  }

  /// 지금 정합성 검사 요청 표식
  public void requestVerify(String adminName) {
    writeControlFile(MigrationControlFile.VERIFY_REQUESTED, adminName);
  }

  /// 정기 동기화 멈춤 표식
  public void pause(String adminName) {
    writeControlFile(MigrationControlFile.SYNC_PAUSED, adminName);
  }

  /**
   * 멈춤 표식 지우기: 지웠으면 true, 원래 없었으면 false
   * 폴더가 없거나 지우기 실패면 MIGRATION_SYNC_REQUEST_FAILED
   */
  public boolean resume() {
    requireSyncDirectory(MigrationControlFile.SYNC_PAUSED);
    try {
      return Files.deleteIfExists(controlFilePath(MigrationControlFile.SYNC_PAUSED));
    } catch (IOException e) {
      log.warn("[migration sync] control file delete failed : file={}", MigrationControlFile.SYNC_PAUSED.getFileName(), e);
      throw new CustomException(ErrorCode.MIGRATION_SYNC_REQUEST_FAILED);
    }
  }

  public boolean isSyncDirectoryPresent() {
    return Files.isDirectory(syncDirectory, LinkOption.NOFOLLOW_LINKS);
  }

  /// 표식 파일 쓰기: 폴더 확인 > 한 줄 "{ISO 시각} {관리자 이름}" (있으면 덮어씀)
  private void writeControlFile(MigrationControlFile controlFile, String adminName) {
    requireSyncDirectory(controlFile);
    String note = DateTimeFormatter.ISO_OFFSET_DATE_TIME.format(OffsetDateTime.now(clock).truncatedTo(ChronoUnit.SECONDS))
      + " " + toNoteAdminName(adminName) + "\n";
    try {
      Files.writeString(controlFilePath(controlFile), note, StandardCharsets.UTF_8);
    } catch (IOException e) {
      log.warn("[migration sync] control file write failed : file={}", controlFile.getFileName(), e);
      throw new CustomException(ErrorCode.MIGRATION_SYNC_REQUEST_FAILED);
    }
  }

  // 버튼은 숨기지만 POST 를 직접 보낼 수 있어 다시 막음
  private void requireSyncDirectory(MigrationControlFile controlFile) {
    if (!isSyncDirectoryPresent()) {
      log.warn("[migration sync] rejected : sync directory missing, file={}", controlFile.getFileName());
      throw new CustomException(ErrorCode.MIGRATION_SYNC_REQUEST_FAILED);
    }
  }

  private boolean hasControlFile(MigrationControlFile controlFile) {
    return Files.exists(controlFilePath(controlFile), LinkOption.NOFOLLOW_LINKS);
  }

  /// 표식 내용 첫 줄 (못 읽으면 null, 화면은 "멈춤" 배지만)
  private String readControlNote(MigrationControlFile controlFile) {
    try (BufferedReader reader = Files.newBufferedReader(controlFilePath(controlFile), StandardCharsets.UTF_8)) {
      String firstLine = reader.readLine();
      if (firstLine == null || firstLine.isBlank()) {
        return null;
      }
      String trimmed = firstLine.strip();
      return trimmed.length() > MAX_CONTROL_NOTE_LENGTH ? trimmed.substring(0, MAX_CONTROL_NOTE_LENGTH) : trimmed;
    } catch (IOException e) {
      log.warn("[migration sync] control note read failed : file={}", controlFile.getFileName(), e);
      return null;
    }
  }

  /// 결과 파일 1개: 없음 > MISSING, 크기 초과·읽기 실패·형식 다름 > UNREADABLE (E-MIG-006)
  private <T> MigrationStatusFileView<T> readStatusFile(String fileName, StatusParser<T> parser) {
    Path file = syncDirectory.resolve(fileName);
    if (!Files.exists(file, LinkOption.NOFOLLOW_LINKS)) {
      return MigrationStatusFileView.missing();
    }
    try {
      if (!Files.isRegularFile(file, LinkOption.NOFOLLOW_LINKS) || Files.size(file) > MAX_STATUS_FILE_BYTES) {
        log.warn("[migration sync] status unreadable : file={} reason=not a regular file or too large", fileName);
        return MigrationStatusFileView.unreadable(unreadableMessage());
      }
      return MigrationStatusFileView.read(parser.parse(Files.readString(file, StandardCharsets.UTF_8)));
    } catch (IOException | MalformedStatusException | RuntimeException e) {
      log.warn("[migration sync] status unreadable : file={} error={} reason={}",
        fileName, e.getClass().getSimpleName(), e.getMessage());
      return MigrationStatusFileView.unreadable(unreadableMessage());
    }
  }

  /// 마지막 동기화가 기준보다 오래됐는가 (기록·시각이 없으면 판정하지 않음)
  private boolean isSyncStale(MigrationStatusFileView<MigrationSyncReport> syncStatus) {
    if (!syncStatus.isRead() || syncStatus.report().lastActivityAt() == null) {
      return false;
    }
    LocalDateTime lastActivityAt = syncStatus.report().lastActivityAt();
    return Duration.between(lastActivityAt, LocalDateTime.now(clock)).toMinutes() >= SYNC_STALE_THRESHOLD_MINUTES;
  }

  private Path controlFilePath(MigrationControlFile controlFile) {
    return syncDirectory.resolve(controlFile.getFileName());
  }

  private static String toNoteAdminName(String adminName) {
    if (adminName == null || adminName.isBlank()) {
      return UNKNOWN_ADMIN_NAME;
    }
    return adminName.strip().replaceAll(NON_NAME_CHARACTERS, "_");
  }

  // 관리자 화면은 한국어 고정 (오류 코드 포함 문구)
  private static String unreadableMessage() {
    return ErrorMessages.standard().of(ErrorCode.MIGRATION_STATUS_UNREADABLE, AppLocale.KO);
  }

  @FunctionalInterface
  private interface StatusParser<T> {
    T parse(String json) throws MalformedStatusException;
  }
}
