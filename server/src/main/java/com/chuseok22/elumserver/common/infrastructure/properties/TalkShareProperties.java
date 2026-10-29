package com.chuseok22.elumserver.common.infrastructure.properties;

import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 이야기 글 공유 링크 설정: 공유 주소 기준, 기본 미리보기 그림, 스토어 주소, 앱 연결 검증 값
 * 앱 식별값(iosAppId·androidPackageName)은 앱 프로젝트 설정과 같아야 링크가 앱으로 열림
 */
@ConfigurationProperties(prefix = "talk.share")
public record TalkShareProperties(
  String publicBaseUrl,
  String defaultImageUrl,
  String playStoreUrl,
  String appStoreUrl,
  String iosAppId,
  String androidPackageName,
  List<String> androidCertSha256
) {

  private static final String DEFAULT_PUBLIC_BASE_URL = "https://api.elum.chuseok22.com";
  // gh-pages 소개 페이지의 미리보기 그림 (1200×630)
  private static final String DEFAULT_IMAGE_URL = "https://twin-fang.github.io/elum/assets/og.png";
  private static final String DEFAULT_PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=kr.twinfang.elum";
  private static final String DEFAULT_APP_STORE_URL = "https://apps.apple.com/kr/app/id6792970508";
  // {Team ID}.{번들 ID} — client/ios/Runner.xcodeproj DEVELOPMENT_TEAM · PRODUCT_BUNDLE_IDENTIFIER
  private static final String DEFAULT_IOS_APP_ID = "CUK22HY6YC.kr.twinfang.elum";
  // client/android/app/build.gradle.kts applicationId
  private static final String DEFAULT_ANDROID_PACKAGE_NAME = "kr.twinfang.elum";
  // App Store 주소의 앱 번호: …/app/id{숫자}
  private static final Pattern APP_STORE_APP_ID_PATTERN = Pattern.compile("/id(\\d+)");

  public TalkShareProperties {
    publicBaseUrl = withoutTrailingSlash(orDefault(publicBaseUrl, DEFAULT_PUBLIC_BASE_URL));
    defaultImageUrl = orDefault(defaultImageUrl, DEFAULT_IMAGE_URL);
    playStoreUrl = orDefault(playStoreUrl, DEFAULT_PLAY_STORE_URL);
    appStoreUrl = orDefault(appStoreUrl, DEFAULT_APP_STORE_URL);
    iosAppId = orDefault(iosAppId, DEFAULT_IOS_APP_ID);
    androidPackageName = orDefault(androidPackageName, DEFAULT_ANDROID_PACKAGE_NAME);
    // 빈 값·공백 항목 제거 (설정이 비면 빈 목록 > 검증 파일도 빈 배열)
    androidCertSha256 = androidCertSha256 == null ? List.of() : androidCertSha256.stream()
      .filter(fingerprint -> fingerprint != null && !fingerprint.isBlank())
      .map(String::trim)
      .toList();
  }

  /**
   * App Store 주소 > 앱 번호 (…/id6792970508 > 6792970508, 없으면 null). Safari 앱 배너용
   */
  public String appStoreAppId() {
    Matcher matcher = APP_STORE_APP_ID_PATTERN.matcher(appStoreUrl);
    return matcher.find() ? matcher.group(1) : null;
  }

  private static String orDefault(String value, String fallback) {
    return value == null || value.isBlank() ? fallback : value.trim();
  }

  private static String withoutTrailingSlash(String url) {
    return url.endsWith("/") ? url.substring(0, url.length() - 1) : url;
  }
}
