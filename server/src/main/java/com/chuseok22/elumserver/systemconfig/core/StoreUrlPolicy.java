package com.chuseok22.elumserver.systemconfig.core;

import java.net.URI;
import java.net.URISyntaxException;
import java.util.Locale;

/**
 * 스토어 주소 설정에 들어갈 수 있는 값 (#416).
 *
 * <p>강제 업데이트로 막힌 사용자는 이 주소 말고 갈 곳이 없다. 엉뚱한 주소가 저장되면
 * 다른 사이트로 보내게 되므로 플랫폼에 맞는 공식 스토어 주소만 받는다.
 * 앱도 같은 규칙으로 한 번 더 거른다 (client {@code AppConfig.storeUrl}).
 */
public final class StoreUrlPolicy {

  private StoreUrlPolicy() {
  }

  /** 이 규칙이 적용되는 키인가. */
  public static boolean appliesTo(ConfigKey key) {
    return key == ConfigKey.IOS_STORE_URL || key == ConfigKey.ANDROID_STORE_URL;
  }

  /** 플랫폼에 맞는 공식 스토어 주소인가. 형식이 깨졌으면 false. */
  public static boolean isAllowed(ConfigKey key, String value) {
    URI uri;
    try {
      uri = new URI(value.trim());
    } catch (URISyntaxException e) {
      return false;
    }
    String scheme = uri.getScheme() == null ? "" : uri.getScheme().toLowerCase(Locale.ROOT);
    // 호스트는 정확히 같아야 한다 — endsWith 로 보면 apps.apple.com.evil.com 이 통과한다
    String host = uri.getHost() == null ? "" : uri.getHost().toLowerCase(Locale.ROOT);
    if (key == ConfigKey.IOS_STORE_URL) {
      return ("https".equals(scheme) || "itms-apps".equals(scheme)) && "apps.apple.com".equals(host);
    }
    if (key == ConfigKey.ANDROID_STORE_URL) {
      // market://details?id=... 는 호스트 자리에 details 가 온다
      return ("https".equals(scheme) && "play.google.com".equals(host))
        || ("market".equals(scheme) && "details".equals(host));
    }
    return false;
  }
}
