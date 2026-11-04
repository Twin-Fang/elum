package com.chuseok22.elumserver.migration.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.migration.application.dto.response.MigrationSyncOverview;
import com.chuseok22.elumserver.migration.core.MigrationControlFile;
import com.chuseok22.elumserver.migration.core.MigrationSyncResult;
import com.chuseok22.elumserver.migration.core.MigrationVerifyResult;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * 서버 이전 동기화 상태 (#1062): 폴더 없음, 결과 JSON 읽기, 깨진 JSON, 오래됨, 표식 파일 만들기·지우기
 * 깨지면: 옛 서버 화면이 죽거나, 깨진 결과를 정상으로 보이거나, 버튼이 NAS 에 요청을 못 남긴다
 */
class MigrationSyncStatusServiceTest {

  private static final ZoneId SEOUL = ZoneId.of("Asia/Seoul");
  // 지금 = 2026-11-04 19:00 (서울)
  private static final Clock NOW_CLOCK = Clock.fixed(Instant.parse("2026-11-04T10:00:00Z"), SEOUL);
  private static final String VALID_SYNC_STATUS = """
    {"startedAt":"2026-11-04T18:39:00+09:00","finishedAt":"2026-11-04T18:43:32+09:00","result":"success",
     "durationSeconds":272,"trigger":"schedule","message":"done","logTail":["line 1","line 2"]}
    """;
  private static final String VALID_VERIFY_STATUS = """
    {"checkedAt":"2026-11-04T18:41:00+09:00","result":"different","differenceCount":1,
     "differences":[{"item":"admin_audit_log","source":"6 abc","target":"2 def"}],"files":"same","isLiveAllowed":true}
    """;

  @TempDir
  Path temporaryDirectory;

  private Path syncDirectory;
  private MigrationSyncStatusService service;

  @BeforeEach
  void setUp() throws IOException {
    syncDirectory = Files.createDirectories(temporaryDirectory.resolve("migration-sync"));
    service = new MigrationSyncStatusService(syncDirectory, NOW_CLOCK);
  }

  private void writeSyncFile(String fileName, String content) throws IOException {
    Files.writeString(syncDirectory.resolve(fileName), content, StandardCharsets.UTF_8);
  }

  @Test
  @DisplayName("동기화 폴더가 없는 서버(옛 서버)는 예외 없이 '정보 없음' 상태 (버튼 숨김)")
  void missingDirectory_reportsNoSyncInformation() {
    MigrationSyncStatusService serviceWithoutDirectory =
      new MigrationSyncStatusService(temporaryDirectory.resolve("absent"), NOW_CLOCK);

    MigrationSyncOverview overview = serviceWithoutDirectory.readOverview();

    assertThat(overview.isSyncDirectoryPresent()).isFalse();
    assertThat(overview.isSyncStale()).isFalse();
  }

  @Test
  @DisplayName("결과 JSON 2개를 읽어 시각(서울)·결과·차이 표를 그대로 보여 준다")
  void validFiles_areParsed() throws IOException {
    writeSyncFile(MigrationSyncStatusService.SYNC_STATUS_FILE_NAME, VALID_SYNC_STATUS);
    writeSyncFile(MigrationSyncStatusService.VERIFY_STATUS_FILE_NAME, VALID_VERIFY_STATUS);

    MigrationSyncOverview overview = service.readOverview();

    assertThat(overview.syncStatus().isRead()).isTrue();
    assertThat(overview.syncStatus().report().result()).isEqualTo(MigrationSyncResult.SUCCESS);
    assertThat(overview.syncStatus().report().finishedAt()).isEqualTo(LocalDateTime.of(2026, 11, 4, 18, 43, 32));
    assertThat(overview.syncStatus().report().durationSeconds()).isEqualTo(272L);
    assertThat(overview.syncStatus().report().logTail()).containsExactly("line 1", "line 2");
    assertThat(overview.verifyStatus().report().result()).isEqualTo(MigrationVerifyResult.DIFFERENT);
    assertThat(overview.verifyStatus().report().differences()).singleElement()
      .satisfies(difference -> assertThat(difference.item()).isEqualTo("admin_audit_log"));
    assertThat(overview.isSyncStale()).isFalse();
  }

  @Test
  @DisplayName("깨진 JSON 은 화면을 죽이지 않고 E-MIG-006 문구로 '읽을 수 없어요' (다른 파일은 그대로)")
  void malformedJson_isUnreadableWithErrorCode() throws IOException {
    writeSyncFile(MigrationSyncStatusService.SYNC_STATUS_FILE_NAME, "{\"result\":\"success\",");
    writeSyncFile(MigrationSyncStatusService.VERIFY_STATUS_FILE_NAME, VALID_VERIFY_STATUS);

    MigrationSyncOverview overview = service.readOverview();

    assertThat(overview.syncStatus().isUnreadable()).isTrue();
    assertThat(overview.syncStatus().errorMessage()).contains("E-MIG-006");
    assertThat(overview.verifyStatus().isRead()).isTrue();
  }

  @Test
  @DisplayName("칸 형식이 약속과 다르면(시각이 ISO 아님) 정상으로 보이지 않고 '읽을 수 없어요'")
  void wrongFieldShape_isUnreadable() throws IOException {
    writeSyncFile(MigrationSyncStatusService.SYNC_STATUS_FILE_NAME,
      "{\"finishedAt\":\"어제 저녁\",\"result\":\"success\"}");

    assertThat(service.readOverview().syncStatus().isUnreadable()).isTrue();
  }

  @Test
  @DisplayName("마지막 동기화가 60분 넘게 지났으면 경고 (NAS 정기 작업이 멈춘 것을 알아챔)")
  void oldFinishedAt_isStale() throws IOException {
    writeSyncFile(MigrationSyncStatusService.SYNC_STATUS_FILE_NAME,
      "{\"finishedAt\":\"2026-11-04T17:59:00+09:00\",\"result\":\"success\"}");

    assertThat(service.readOverview().isSyncStale()).isTrue();
  }

  @Test
  @DisplayName("멈춤·재개: 표식을 만들고 지운다. 내용은 한 줄 '{ISO 시각} {관리자}'")
  void pauseAndResume_toggleMarker() throws IOException {
    Path pausedMarker = syncDirectory.resolve(MigrationControlFile.SYNC_PAUSED.getFileName());

    service.pause("admin one");

    assertThat(Files.readString(pausedMarker)).isEqualTo("2026-11-04T19:00:00+09:00 admin_one\n");
    assertThat(service.readOverview().isPaused()).isTrue();

    assertThat(service.resume()).isTrue();
    assertThat(pausedMarker).doesNotExist();
    assertThat(service.resume()).isFalse();
  }

  @Test
  @DisplayName("지금 동기화·지금 검사는 각자 요청 표식을 남긴다 (NAS 1분 작업이 보고 실행)")
  void requests_createMarkers() {
    service.requestSync("admin");
    service.requestVerify("admin");

    MigrationSyncOverview overview = service.readOverview();
    assertThat(overview.isSyncRequested()).isTrue();
    assertThat(overview.isVerifyRequested()).isTrue();
    assertThat(overview.isPaused()).isFalse();
  }

  @Test
  @DisplayName("폴더가 없는 서버에 요청을 직접 보내면 E-MIG-007 (폴더를 새로 만들지 않음)")
  void requestWithoutDirectory_fails() {
    Path absentDirectory = temporaryDirectory.resolve("absent");
    MigrationSyncStatusService serviceWithoutDirectory = new MigrationSyncStatusService(absentDirectory, NOW_CLOCK);

    assertThatThrownBy(() -> serviceWithoutDirectory.requestSync("admin"))
      .isInstanceOfSatisfying(CustomException.class,
        exception -> assertThat(exception.getErrorCode()).isEqualTo(ErrorCode.MIGRATION_SYNC_REQUEST_FAILED));
    assertThat(absentDirectory).doesNotExist();
  }
}
