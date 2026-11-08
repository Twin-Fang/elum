package com.chuseok22.elumserver.common.infrastructure.properties;

import java.util.List;
import java.util.stream.Stream;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 관제소 확인할 일 수집(attention v1) 설정: 수집 토큰 현재·이전 값, 관리자 화면 기준 주소 (#1229)
 * 토큰은 환경 변수로만 받음 (DB·화면에 두지 않음). 둘 다 비면 모든 수집 요청 401
 */
@ConfigurationProperties(prefix = "elum.control-tower.attention")
public record ControlTowerAttentionProperties(
  String token,
  String previousToken,
  String adminBaseUrl
) {

  private static final String HTTPS_SCHEME_PREFIX = "https://";

  public ControlTowerAttentionProperties {
    token = trimToEmpty(token);
    previousToken = trimToEmpty(previousToken);
    adminBaseUrl = BaseUrls.withoutTrailingSlash(trimToEmpty(adminBaseUrl));
  }

  /// 비어 있지 않은 토큰만 (현재 먼저, 교체 기간의 이전 값)
  public List<String> acceptedTokens() {
    return Stream.of(token, previousToken).filter(acceptedToken -> !acceptedToken.isEmpty()).toList();
  }

  public boolean hasAnyToken() {
    return !acceptedTokens().isEmpty();
  }

  /// 관제소 규격: admin_base_url 은 https 절대 주소만
  public boolean hasHttpsAdminBaseUrl() {
    return adminBaseUrl.startsWith(HTTPS_SCHEME_PREFIX);
  }

  private static String trimToEmpty(String text) {
    return text == null ? "" : text.trim();
  }
}
