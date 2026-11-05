package com.chuseok22.elumserver.admin.infrastructure.security;

import com.chuseok22.elumserver.common.infrastructure.constant.SecurityPaths;
import com.chuseok22.elumserver.common.infrastructure.store.SharedStateStore;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.security.core.Authentication;
import org.springframework.security.web.authentication.SimpleUrlAuthenticationSuccessHandler;

/**
 * 관리자 로그인 성공: 그 아이디의 시도 기록 지움 > 대시보드로 이동 (#1102)
 * 성공한 로그인이 한도에 쌓이지 않아 실패만 센다
 */
public class AdminLoginSuccessHandler extends SimpleUrlAuthenticationSuccessHandler {

  private final SharedStateStore sharedStateStore;

  public AdminLoginSuccessHandler(SharedStateStore sharedStateStore) {
    super(SecurityPaths.ADMIN_DASHBOARD);
    // 저장된 요청 주소와 상관없이 언제나 대시보드로
    setAlwaysUseDefaultTargetUrl(true);
    this.sharedStateStore = sharedStateStore;
  }

  @Override
  public void onAuthenticationSuccess(
    HttpServletRequest request,
    HttpServletResponse response,
    Authentication authentication
  ) throws IOException, ServletException {
    sharedStateStore.clearWindow(AdminLoginAttemptFilter.attemptKeyOf(request));
    super.onAuthenticationSuccess(request, response, authentication);
  }
}
