package com.chuseok22.elumserver.systemconfig.core;

import java.net.URI;
import java.net.URISyntaxException;
import java.util.Set;

/**
 * 앱이 옮겨 갈 수 있는 서버 주소 규칙: https, 허용 도메인 2개, 경로·쿼리 없음
 * 앱 허용 목록(client/lib/core/config/server_address_policy.dart, CrossStackContractTest 가 대조)과 같은 목록이어야 한다 — 관리자가 오타를 내도 사용자 토큰이 엉뚱한 곳으로 가지 않게
 */
public final class ServerAddressPolicy {

  // 운영 도메인 2개: 기존 서버(친구 NAS), 새 서버(내 NAS)
  public static final Set<String> ALLOWED_API_HOSTS = Set.of(
    "api.elum.chuseok22.com",
    "api.elum.suhsaechan.kr"
  );
  private static final String REQUIRED_SCHEME = "https";

  private ServerAddressPolicy() {
  }

  /// 허용된 서버 주소인가 (끝의 / 하나는 허용)
  public static boolean isAllowed(String value) {
    if (value == null || value.isBlank()) {
      return false;
    }
    try {
      URI uri = new URI(value.trim());
      String path = uri.getRawPath();
      return REQUIRED_SCHEME.equalsIgnoreCase(uri.getScheme())
        && uri.getHost() != null
        && ALLOWED_API_HOSTS.contains(uri.getHost().toLowerCase())
        && uri.getPort() == -1
        && uri.getRawUserInfo() == null
        && uri.getRawQuery() == null
        && uri.getRawFragment() == null
        && (path == null || path.isEmpty() || path.equals("/"));
    } catch (URISyntaxException e) {
      return false;
    }
  }
}
