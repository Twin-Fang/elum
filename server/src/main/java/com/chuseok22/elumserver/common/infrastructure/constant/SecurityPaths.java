package com.chuseok22.elumserver.common.infrastructure.constant;

public final class SecurityPaths {

  public static final String ADMIN_MATCHER = "/admin/**";
  public static final String ADMIN_LOGIN = "/admin/login";
  public static final String ADMIN_DASHBOARD = "/admin/dashboard";
  public static final String ADMIN_LOGOUT = "/admin/logout";
  public static final String API_MATCHER = "/api/**";
  public static final String API_AUTH_MATCHER = "/api/auth/**";
  /** 이룸이 휴대폰이 연결 암호를 넣는 곳. 로그인 전에 부르므로 인증이 없다 (이슈 #200). */
  public static final String API_DEVICE_LINK_REDEEM = "/api/device-links/redeem";
  public static final String DOCS_SWAGGER = "/docs/swagger";
  public static final String DOCS_SWAGGER_UI_MATCHER = "/docs/swagger-ui/**";
  public static final String DOCS_API_DOCS_MATCHER = "/v3/api-docs/**";

  private SecurityPaths() {
  }
}
