package com.chuseok22.elumserver.common.infrastructure.properties;

/**
 * 설정의 기준 주소 정리 공통: 끝 / 하나 제거 (뒤에 "/경로" 를 붙여 쓰므로)
 */
final class BaseUrls {

  private static final String TRAILING_SLASH = "/";

  private BaseUrls() {
  }

  static String withoutTrailingSlash(String url) {
    return url.endsWith(TRAILING_SLASH) ? url.substring(0, url.length() - 1) : url;
  }
}
