package com.chuseok22.elumserver.common.infrastructure.storage;

import java.util.Locale;

/**
 * 저장 그림 형식 변환: 형식 > 확장자, 열쇠 확장자 > 형식
 * 운영체제 추측(probeContentType)은 환경마다 달라 쓰지 않음
 */
public final class StoredImageFormat {

  private static final String DEFAULT_EXTENSION = "jpg";
  private static final String UNKNOWN_CONTENT_TYPE = "application/octet-stream";

  private StoredImageFormat() {
  }

  /// 형식 > 확장자 (모르면 jpg)
  public static String extensionOf(String contentType) {
    if (contentType == null) {
      return DEFAULT_EXTENSION;
    }
    return switch (contentType.toLowerCase(Locale.ROOT)) {
      case "image/png" -> "png";
      case "image/webp" -> "webp";
      default -> DEFAULT_EXTENSION;
    };
  }

  /// 열쇠 확장자 > 형식
  public static String contentTypeOf(String key) {
    int dot = key.lastIndexOf('.');
    String extension = dot < 0 ? "" : key.substring(dot + 1).toLowerCase(Locale.ROOT);
    return switch (extension) {
      case "jpg", "jpeg" -> "image/jpeg";
      case "png" -> "image/png";
      case "webp" -> "image/webp";
      default -> UNKNOWN_CONTENT_TYPE;
    };
  }
}
