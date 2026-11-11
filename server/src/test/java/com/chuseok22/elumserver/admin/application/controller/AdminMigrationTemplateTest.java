package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.dto.response.SettingRow;
import com.chuseok22.elumserver.admin.application.dto.response.SettingsEditorView;
import com.chuseok22.elumserver.migration.application.dto.response.MigrationStatusFileView;
import com.chuseok22.elumserver.migration.application.dto.response.MigrationSyncOverview;
import com.chuseok22.elumserver.migration.core.MigrationVerifyReport;
import com.chuseok22.elumserver.migration.core.MigrationVerifyResult;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 서버 이전 화면 (#1062): 폴더 없는 서버는 버튼 숨김, 깨진 결과에도 화면이 그려짐, 이전 설정을 그 자리에서 고침
 * 서버를 띄우지 않고 템플릿 엔진만으로 그린다
 */
class AdminMigrationTemplateTest {

  private static final SettingRow MIGRATION_LOCK_ROW = new SettingRow("MIGRATION_LOCK", "이전 잠금", "설명", "MIGRATION",
    "서버 이전", "BOOLEAN", List.of(), null, null, "false", "꺼짐", "false", "꺼짐", false, false, false, null, null, null,
    "FREE_TEXT", "", null, "코드 기본값", null);
  private static final SettingsEditorView SETTINGS = new SettingsEditorView("/admin/migration", List.of(MIGRATION_LOCK_ROW),
    Map.of("MIGRATION", "서버 이전"), 0, LocalDate.of(2026, 11, 8), null);

  private final AdminTemplateRenderSupport renderer = new AdminTemplateRenderSupport();

  @Test
  @DisplayName("동기화 폴더가 없는 서버는 안내만 보이고 동기화·검사 버튼이 없다")
  void withoutSyncDirectory_hidesButtons() {
    String html = renderer.render("admin/migration", Map.of(
      "overview", MigrationSyncOverview.withoutSyncDirectory(60),
      "editor", SETTINGS));

    assertThat(html)
      .contains("이 서버에는 동기화 정보가 없어요", "이전 잠금")
      .doesNotContain("/admin/migration/sync-request", "/admin/migration/verify-request", "/admin/migration/pause");
  }

  @Test
  @DisplayName("동기화 결과가 깨져도 오류 코드와 함께 그려지고, 검사 차이 표와 버튼은 그대로 보인다")
  void unreadableSync_showsErrorCodeAndKeepsButtons() {
    MigrationVerifyReport verifyReport = new MigrationVerifyReport(LocalDateTime.of(2026, 11, 4, 18, 41),
      MigrationVerifyResult.DIFFERENT, "different", 1,
      List.of(new MigrationVerifyReport.Difference("admin_audit_log", "6 abc", "2 def")), "same", true);
    MigrationSyncOverview overview = new MigrationSyncOverview(true,
      MigrationStatusFileView.unreadable("이전 상태 파일을 읽을 수 없어요. (E-MIG-006)"),
      MigrationStatusFileView.read(verifyReport), true, "2026-11-04T18:00:00+09:00 admin", false, true, false, 60);

    String html = renderer.render("admin/migration", Map.of(
      "overview", overview, "editor", SETTINGS));

    assertThat(html)
      .contains("E-MIG-006", "차이 있음", "admin_audit_log", "2026-11-04 18:41", "요청 대기 중")
      .contains("/admin/migration/sync-request", "/admin/migration/verify-request", "/admin/migration/resume")
      .doesNotContain("/admin/migration/pause");
  }

  @Test
  @DisplayName("이전 설정은 이 화면 표에서 바로 고친다 (저장 뒤 이 화면을 다시 받음)")
  void migrationSettings_editableInPlace() {
    String html = renderer.render("admin/migration", Map.of(
      "overview", MigrationSyncOverview.withoutSyncDirectory(60), "editor", SETTINGS));

    assertThat(html)
      .contains("data-key=\"MIGRATION_LOCK\"", "data-refresh-url=\"/admin/migration\"", "data-settings-panel")
      .doesNotContain("시스템 설정에서 바꾸기");
  }
}
