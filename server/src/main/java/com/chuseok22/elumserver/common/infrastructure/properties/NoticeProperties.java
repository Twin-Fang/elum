package com.chuseok22.elumserver.common.infrastructure.properties;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 공지 이미지를 둘 폴더 (이슈 #370). {@link RoutineProperties} 와 같은 관례다.
 *
 * <p>기본값이 상대 경로인 이유 — 운영 컨테이너는 작업 폴더({@code /app})를 통째로 호스트에
 * 붙여 두므로 {@code data/notice-images} 도 재배포에 살아남는다. 일과 이미지가 같은 방식으로
 * {@code data/routine-images} 에 있다.
 */
@ConfigurationProperties(prefix = "notice")
public record NoticeProperties(String imageStoragePath) {

  private static final String DEFAULT_IMAGE_STORAGE_PATH = "data/notice-images";

  public NoticeProperties {
    if (imageStoragePath == null || imageStoragePath.isBlank()) {
      imageStoragePath = DEFAULT_IMAGE_STORAGE_PATH;
    }
  }
}
