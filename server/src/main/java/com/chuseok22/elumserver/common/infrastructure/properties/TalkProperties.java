package com.chuseok22.elumserver.common.infrastructure.properties;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 이야기 설정: 그림 사본 저장 폴더, 신고 알림 받을 메일(없으면 메일 안 보냄)
 */
@ConfigurationProperties(prefix = "talk")
public record TalkProperties(String imageStoragePath, String reportMailTo) {

  private static final String DEFAULT_IMAGE_STORAGE_PATH = "data/talk-images";

  public TalkProperties {
    if (imageStoragePath == null || imageStoragePath.isBlank()) {
      imageStoragePath = DEFAULT_IMAGE_STORAGE_PATH;
    }
    if (reportMailTo != null && reportMailTo.isBlank()) {
      reportMailTo = null;
    }
  }
}
