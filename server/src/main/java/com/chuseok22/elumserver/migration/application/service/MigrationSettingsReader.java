package com.chuseok22.elumserver.migration.application.service;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorMessages;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.migration.application.dto.response.MigrationSettingsView;
import com.chuseok22.elumserver.migration.application.dto.response.MigrationSettingsView.Row;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 이전 설정 3개 읽기 (#1062): 이전 잠금, 이전 파일 내보내기, 새 서버 주소
 * 바꾸는 곳은 시스템 설정 화면뿐. 여기는 보여 주기만
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class MigrationSettingsReader {

  private static final String ENABLED_TEXT = "켜짐";
  private static final String DISABLED_TEXT = "꺼짐";
  private static final String EMPTY_ADDRESS_TEXT = "비어 있음 (앱은 지금 주소를 써요)";

  private final SystemConfigService systemConfigService;

  /// 설정 3개 > 표시 줄 (읽기 실패면 줄 없이 안내 문구)
  public MigrationSettingsView read() {
    try {
      boolean isLocked = systemConfigService.getBoolean(ConfigKey.MIGRATION_LOCK);
      boolean isFileExportEnabled = systemConfigService.getBoolean(ConfigKey.MIGRATION_FILE_EXPORT_ENABLED);
      String newServerBaseUrl = systemConfigService.getString(ConfigKey.APP_API_BASE_URL);
      boolean hasNewServerBaseUrl = newServerBaseUrl != null && !newServerBaseUrl.isBlank();
      return new MigrationSettingsView(List.of(
        new Row(ConfigKey.MIGRATION_LOCK.getLabel(), onOffText(isLocked), isLocked),
        new Row(ConfigKey.MIGRATION_FILE_EXPORT_ENABLED.getLabel(), onOffText(isFileExportEnabled), isFileExportEnabled),
        new Row(ConfigKey.APP_API_BASE_URL.getLabel(),
          hasNewServerBaseUrl ? newServerBaseUrl.trim() : EMPTY_ADDRESS_TEXT, hasNewServerBaseUrl)
      ), null);
    } catch (RuntimeException e) {
      log.warn("[migration status] settings read failed", e);
      // 칸 대신 안내 문구 + 오류 코드 (E-MIG-008)
      return new MigrationSettingsView(List.of(), ErrorMessages.standard().of(ErrorCode.MIGRATION_SETTINGS_UNREADABLE, AppLocale.KO));
    }
  }

  private static String onOffText(boolean isEnabled) {
    return isEnabled ? ENABLED_TEXT : DISABLED_TEXT;
  }
}
