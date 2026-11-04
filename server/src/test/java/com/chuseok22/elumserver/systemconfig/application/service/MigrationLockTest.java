package com.chuseok22.elumserver.systemconfig.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 이전 잠금 판정: 새 서버 주소 정리, 설정 실패 시 잠기지 않음, 예약 작업 건너뛰기 (#1053)
 * 깨지면: 광고 보상·공유 링크가 잘못된 주소로 가거나, 설정 오류 한 번에 서버 전체가 멈춘다
 */
class MigrationLockTest {

  private final SystemConfigService systemConfigService = mock(SystemConfigService.class);
  private final MigrationLock migrationLock = new MigrationLock(systemConfigService);

  @Test
  @DisplayName("새 서버 주소는 앞뒤 공백과 끝 / 를 뗀다")
  void newServerBaseUrl_trimsTrailingSlash() {
    when(systemConfigService.getString(ConfigKey.APP_API_BASE_URL)).thenReturn(" https://api.elum.suhsaechan.kr/ ");
    assertThat(migrationLock.newServerBaseUrl()).contains("https://api.elum.suhsaechan.kr");
  }

  @Test
  @DisplayName("새 서버 주소가 비면 없음")
  void newServerBaseUrl_blank_isEmpty() {
    when(systemConfigService.getString(ConfigKey.APP_API_BASE_URL)).thenReturn("  ");
    assertThat(migrationLock.newServerBaseUrl()).isEmpty();
  }

  @Test
  @DisplayName("설정을 못 읽으면 잠기지 않은 것으로 본다")
  void isLocked_configFails_isFalse() {
    when(systemConfigService.getBoolean(ConfigKey.MIGRATION_LOCK)).thenThrow(new IllegalStateException("DB"));
    assertThat(migrationLock.isLocked()).isFalse();
  }

  @Test
  @DisplayName("잠겼으면 예약 작업을 건너뛴다")
  void isBlockingScheduledJob_locked_isTrue() {
    when(systemConfigService.getBoolean(ConfigKey.MIGRATION_LOCK)).thenReturn(true);
    assertThat(migrationLock.isBlockingScheduledJob("TestJob")).isTrue();
  }

  @Test
  @DisplayName("잠기지 않았으면 예약 작업을 그대로 돈다")
  void isBlockingScheduledJob_unlocked_isFalse() {
    when(systemConfigService.getBoolean(ConfigKey.MIGRATION_LOCK)).thenReturn(false);
    assertThat(migrationLock.isBlockingScheduledJob("TestJob")).isFalse();
  }
}
