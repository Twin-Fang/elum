package com.chuseok22.elumserver.common.infrastructure.properties;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 서버 이전 상태 화면 설정 (#1062): NAS 동기화 정보 폴더, 옛 서버 주소
 * 폴더 기본값은 컨테이너 작업 폴더(/app) 기준 상대 경로 (호스트 /volume1/project/elum/server/migration-sync)
 */
@ConfigurationProperties(prefix = "elum.migration")
public record MigrationProperties(String syncDir, String sourceBaseUrl) {

  private static final String DEFAULT_SYNC_DIR = "migration-sync";
  private static final String DEFAULT_SOURCE_BASE_URL = "https://api.elum.chuseok22.com";

  public MigrationProperties {
    syncDir = syncDir == null || syncDir.isBlank() ? DEFAULT_SYNC_DIR : syncDir.trim();
    sourceBaseUrl = sourceBaseUrl == null || sourceBaseUrl.isBlank()
      ? DEFAULT_SOURCE_BASE_URL
      : BaseUrls.withoutTrailingSlash(sourceBaseUrl.trim());
  }
}
