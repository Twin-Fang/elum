package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.admin.application.dto.response.SettingRow;
import com.chuseok22.elumserver.admin.application.dto.response.SettingsEditorView;
import com.chuseok22.elumserver.admin.application.dto.response.SettingsSectionLink;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 화면별 설정 칸: 모든 설정이 정확히 한 화면에 나옴, 다른 화면 바로가기 수, 읽기 실패 안내
 */
class SettingsEditorServiceTest {

  private static final LocalDate TODAY = LocalDate.of(2026, 11, 8);

  private final SystemConfigOverviewService overviewService = mock(SystemConfigOverviewService.class);
  private final SettingsEditorService service = new SettingsEditorService(overviewService);

  /// 실제 설정 키 전부를 행으로 (짝수 번째만 기본값과 다름)
  private static List<SettingRow> rowsOfAllKeys() {
    List<SettingRow> rows = new ArrayList<>();
    ConfigKey[] keys = ConfigKey.values();
    for (int index = 0; index < keys.length; index++) {
      ConfigKey key = keys[index];
      rows.add(new SettingRow(key.name(), key.getLabel(), "", key.getGroup().name(), key.getGroup().getLabel(),
        key.getValueType().name(), List.of(), null, null, "", "", "", "", index % 2 == 0, false, false, null, null,
        null, "FREE_TEXT", "", null, "코드 기본값", null));
    }
    return rows;
  }

  @Test
  @DisplayName("모든 설정 키가 정확히 한 화면의 표에 들어간다 — 옮기다 빠진 설정은 어느 화면에서도 고칠 수 없게 된다")
  void everyKey_appearsInExactlyOneSection() {
    List<SettingRow> allRows = rowsOfAllKeys();

    List<String> shownKeys = Arrays.stream(SettingsSection.values())
      .flatMap(section -> service.buildEditor(section, allRows, TODAY).rows().stream())
      .map(SettingRow::key)
      .toList();

    assertThat(shownKeys).hasSize(ConfigKey.values().length).doesNotHaveDuplicates();
  }

  @Test
  @DisplayName("화면마다 그 화면 묶음만 보인다: AI 화면에 플랜 한도가, 시스템 화면에 AI 모델이 섞이지 않는다")
  void section_showsOnlyItsGroups() {
    List<SettingRow> allRows = rowsOfAllKeys();

    List<String> aiKeys = service.buildEditor(SettingsSection.AI, allRows, TODAY).rows().stream().map(SettingRow::key).toList();
    List<String> systemKeys = service.buildEditor(SettingsSection.SYSTEM, allRows, TODAY).rows().stream().map(SettingRow::key).toList();
    List<String> migrationKeys = service.buildEditor(SettingsSection.MIGRATION, allRows, TODAY).rows().stream()
      .map(SettingRow::key).toList();

    assertThat(aiKeys).contains("AI_DAILY_BUDGET_USD", "CLAUDE_TEXT_MODEL").doesNotContain("FREE_ADS_REMOVED");
    assertThat(systemKeys).contains("MAINTENANCE_MODE", "MEMBER_WITHDRAWN_RETENTION_DAYS")
      .doesNotContain("GEMINI_TEXT_MODEL", "MIGRATION_LOCK");
    assertThat(migrationKeys).containsExactlyInAnyOrder("MIGRATION_LOCK", "MIGRATION_FILE_EXPORT_ENABLED", "APP_API_BASE_URL");
  }

  @Test
  @DisplayName("다른 화면 바로가기는 시스템 화면을 빼고, 화면별 설정 수와 기본값과 다른 수를 센다")
  void sectionLinks_countSettingsPerSection() {
    List<SettingRow> allRows = rowsOfAllKeys();

    List<SettingsSectionLink> links = service.sectionLinksOf(allRows);
    long systemCount = service.buildEditor(SettingsSection.SYSTEM, allRows, TODAY).rows().size();

    assertThat(links).extracting(SettingsSectionLink::label).doesNotContain(SettingsSection.SYSTEM.getLabel());
    assertThat(links.stream().mapToLong(SettingsSectionLink::settingCount).sum() + systemCount)
      .isEqualTo(ConfigKey.values().length);
    SettingsSectionLink migrationLink = links.stream()
      .filter(link -> link.path().equals(SettingsSection.MIGRATION.getPath())).findFirst().orElseThrow();
    assertThat(migrationLink.settingCount()).isEqualTo(3);
  }

  @Test
  @DisplayName("다른 기능 화면에 얹는 설정 칸은 읽기 실패해도 예외 없이 오류 코드 안내만 준다 — 광고 보상 목록까지 깨지지 않는다")
  void buildEditorOrFailure_readFailure_returnsErrorView() {
    when(overviewService.buildRows()).thenThrow(new IllegalStateException("db down"));

    SettingsEditorView editor = service.buildEditorOrFailure(SettingsSection.AD_REWARD);

    assertThat(editor.isLoaded()).isFalse();
    assertThat(editor.loadErrorMessage()).contains("E-CFG-LOAD");
    assertThat(editor.rows()).isEmpty();
  }
}
