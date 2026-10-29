package com.chuseok22.elumserver.talk.application.dto.request;

import java.util.List;
import java.util.Locale;

/**
 * 공유 페이지를 연 기기 (User-Agent 기준): 플랫폼 3갈래(android, ios, other), 앱 내장 브라우저 여부
 * 스토어 버튼 고르기, 페이지가 뜨자마자 앱을 부를지 정할 때 씀
 */
public record TalkShareVisitor(String platform, boolean isInAppBrowser) {

  public static final String PLATFORM_ANDROID = "android";
  public static final String PLATFORM_IOS = "ios";
  public static final String PLATFORM_OTHER = "other";

  // 내장 브라우저 UA 표식 7개: 카카오톡, 네이버, 인스타그램, 페이스북 2종, 라인, 다음
  private static final List<String> IN_APP_BROWSER_MARKERS =
    List.of("kakaotalk", "naver(inapp", "instagram", "fban", "fbav", "line/", "daumapps");

  /**
   * User-Agent > 기기 (없으면 other, 내장 브라우저 아님)
   */
  public static TalkShareVisitor from(String userAgent) {
    String lowered = userAgent == null ? "" : userAgent.toLowerCase(Locale.ROOT);
    boolean isInAppBrowser = IN_APP_BROWSER_MARKERS.stream().anyMatch(lowered::contains);
    return new TalkShareVisitor(platformOf(lowered), isInAppBrowser);
  }

  public boolean isAndroid() {
    return PLATFORM_ANDROID.equals(platform);
  }

  public boolean isIos() {
    return PLATFORM_IOS.equals(platform);
  }

  private static String platformOf(String loweredUserAgent) {
    if (loweredUserAgent.contains("android")) {
      return PLATFORM_ANDROID;
    }
    if (loweredUserAgent.contains("iphone") || loweredUserAgent.contains("ipad") || loweredUserAgent.contains("ipod")) {
      return PLATFORM_IOS;
    }
    return PLATFORM_OTHER;
  }
}
