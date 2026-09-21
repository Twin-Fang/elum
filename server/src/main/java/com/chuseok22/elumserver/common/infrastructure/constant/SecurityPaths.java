package com.chuseok22.elumserver.common.infrastructure.constant;

public final class SecurityPaths {

  public static final String ADMIN_MATCHER = "/admin/**";
  public static final String ADMIN_LOGIN = "/admin/login";
  public static final String ADMIN_DASHBOARD = "/admin/dashboard";
  public static final String ADMIN_LOGOUT = "/admin/logout";
  /**
   * 관리자 화면이 쓰는 CSS·JS. **로그인 전에도 받을 수 있어야 한다** (이슈 #248).
   *
   * <p>막아 두면 브라우저가 이 파일을 요청했을 때 로그인 페이지(HTML)가 돌아오고,
   * MIME 타입이 맞지 않아 스타일과 스크립트가 통째로 무시된다. 로그인 화면부터
   * 글자만 남는다.
   */
  public static final String ADMIN_ASSETS_MATCHER = "/admin/vendor/**";
  public static final String ADMIN_SCRIPTS_MATCHER = "/admin/js/**";
  public static final String API_MATCHER = "/api/**";
  public static final String API_AUTH_MATCHER = "/api/auth/**";
  /**
   * 토큰 갱신. <b>점검 중에도 연다</b> (이슈 #279).
   *
   * <p>갱신이 503을 받으면 앱은 세션이 끝난 것으로 처리할 수 있다. 점검 한 번에 모든 사용자가
   * 로그아웃되지 않게 이 경로만은 막지 않는다.
   */
  public static final String API_AUTH_REFRESH = "/api/auth/refresh";
  /** 이룸이 휴대폰이 연결 암호를 넣는 곳. 로그인 전에 부르므로 인증이 없다 (이슈 #200). */
  public static final String API_DEVICE_LINK_REDEEM = "/api/device-links/redeem";
  /**
   * 앱이 시작하며 서버 상태를 묻는 곳 (이슈 #279).
   *
   * <p>인증이 없다. 로그인 전에도, <b>점검 중에도</b> 부를 수 있어야 한다 —
   * 여기까지 막으면 앱이 점검 사실을 받을 방법이 없어 무한 로딩으로 보인다.
   */
  public static final String API_APP_STATUS = "/api/app/status";
  /**
   * 약관 전문을 주는 곳 (이슈 #278).
   *
   * <p>인증이 없다. <b>가입하기 전에 읽는 문서</b>라 로그인을 요구할 수 없다.
   */
  public static final String API_CONSENT_DOCUMENTS = "/api/consents/documents";
  public static final String DOCS_SWAGGER = "/docs/swagger";
  public static final String DOCS_SWAGGER_UI_MATCHER = "/docs/swagger-ui/**";
  public static final String DOCS_API_DOCS_MATCHER = "/v3/api-docs/**";

  private SecurityPaths() {
  }
}
