package com.chuseok22.elumserver.systemconfig.application.service;

import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 서버 이전 잠금 판정: 잠김 여부, 예약 작업 건너뛰기, 새 서버 주소
 * 잠금을 묻는 곳(점검 필터·푸시·신고 메일·예약 작업·광고 보상 콜백·공유 링크)은 모두 이 클래스만 본다 (#1053)
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class MigrationLock {

  private static final String TRAILING_SLASH = "/";

  private final SystemConfigService systemConfigService;

  /// 이전 잠금이 켜져 있는가 (설정을 못 읽으면 잠기지 않은 것으로, 점검 모드와 같은 기준)
  public boolean isLocked() {
    try {
      return systemConfigService.getBoolean(ConfigKey.MIGRATION_LOCK);
    } catch (RuntimeException e) {
      log.warn("[migration lock] config read failed : treat as unlocked", e);
      return false;
    }
  }

  /// 예약 작업 첫 줄에서 부른다: 잠겼으면 건너뛰기 로그를 남기고 true
  public boolean isBlockingScheduledJob(String jobName) {
    if (!isLocked()) {
      return false;
    }
    log.info("[migration lock] scheduled job skipped : {}", jobName);
    return true;
  }

  /// 새 서버 주소 (앞뒤 공백·끝 / 제거, 비면 empty)
  public Optional<String> newServerBaseUrl() {
    String configuredBaseUrl = systemConfigService.getString(ConfigKey.APP_API_BASE_URL);
    if (configuredBaseUrl == null || configuredBaseUrl.isBlank()) {
      return Optional.empty();
    }
    String trimmed = configuredBaseUrl.trim();
    while (trimmed.endsWith(TRAILING_SLASH)) {
      trimmed = trimmed.substring(0, trimmed.length() - 1);
    }
    return trimmed.isEmpty() ? Optional.empty() : Optional.of(trimmed);
  }
}
