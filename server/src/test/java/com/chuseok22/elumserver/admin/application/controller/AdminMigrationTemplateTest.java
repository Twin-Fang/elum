package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.migration.application.dto.response.MigrationSettingsView;
import com.chuseok22.elumserver.migration.application.dto.response.MigrationStatusFileView;
import com.chuseok22.elumserver.migration.application.dto.response.MigrationSyncOverview;
import com.chuseok22.elumserver.migration.application.dto.response.SourceServerProbeView;
import com.chuseok22.elumserver.migration.application.dto.response.SourceServerProbeView.State;
import com.chuseok22.elumserver.migration.core.MigrationVerifyReport;
import com.chuseok22.elumserver.migration.core.MigrationVerifyResult;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 서버 이전 화면 (#1062): 폴더 없는 서버는 버튼 숨김, 깨진 결과·옛 서버 무응답에도 화면이 그려짐
 * 서버를 띄우지 않고 템플릿 엔진만으로 그린다
 */
class AdminMigrationTemplateTest {

  private static final SourceServerProbeView UNREACHABLE_PROBE = new SourceServerProbeView(
    "https://api.elum.chuseok22.com", "https://api.elum.suhsaechan.kr", State.UNREACHABLE, null,
    "HttpTimeoutException", null, null, false);
  private static final MigrationSettingsView SETTINGS = new MigrationSettingsView(
    List.of(new MigrationSettingsView.Row("이전 잠금", "꺼짐", false)), null);

  private final AdminTemplateRenderSupport renderer = new AdminTemplateRenderSupport();

  @Test
  @DisplayName("동기화 폴더가 없는 서버(옛 서버)는 안내만 보이고 동기화·검사 버튼이 없다")
  void withoutSyncDirectory_hidesButtons() {
    String html = renderer.render("admin/migration", Map.of(
      "overview", MigrationSyncOverview.withoutSyncDirectory(60),
      "settings", SETTINGS,
      "probe", UNREACHABLE_PROBE));

    assertThat(html)
      .contains("이 서버에는 동기화 정보가 없어요", "이전 잠금", "응답 없음", "HttpTimeoutException")
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
      "overview", overview, "settings", SETTINGS, "probe", UNREACHABLE_PROBE));

    assertThat(html)
      .contains("E-MIG-006", "차이 있음", "admin_audit_log", "2026-11-04 18:41", "요청 대기 중")
      .contains("/admin/migration/sync-request", "/admin/migration/verify-request", "/admin/migration/resume")
      .doesNotContain("/admin/migration/pause");
  }
}
