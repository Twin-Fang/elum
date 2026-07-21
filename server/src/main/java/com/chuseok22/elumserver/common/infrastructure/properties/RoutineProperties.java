package com.chuseok22.elumserver.common.infrastructure.properties;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "routine")
public record RoutineProperties(String imageStoragePath) {

  private static final String DEFAULT_IMAGE_STORAGE_PATH = "data/routine-images";

  public RoutineProperties {
    if (imageStoragePath == null || imageStoragePath.isBlank()) {
      imageStoragePath = DEFAULT_IMAGE_STORAGE_PATH;
    }
  }
}
