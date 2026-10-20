package com.chuseok22.elumserver.admin.infrastructure.security;

import com.chuseok22.elumserver.common.infrastructure.constant.SecurityPaths;
import com.chuseok22.elumserver.common.infrastructure.store.SharedStateStore;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.Duration;
import java.util.Locale;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpMethod;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * 관리자 로그인 시도 제한: 아이디별 15분 안에 5회
 * 한도 초과 > 인증을 거치지 않고 로그인 화면으로 되돌림 (거부된 시도는 창에 남기지 않아 시간이 지나면 풀림)
 */
@Slf4j
@RequiredArgsConstructor
public class AdminLoginAttemptFilter extends OncePerRequestFilter {

  // 아이디별 허용 횟수 (로그인 성공도 센다, 관리자는 로그인이 드물다)
  private static final int MAX_ATTEMPTS_PER_WINDOW = 5;
  private static final Duration ATTEMPT_WINDOW = Duration.ofMinutes(15);
  private static final String KEY_PREFIX = "admin-login:";
  private static final String USERNAME_PARAMETER = "username";
  // 열쇠 길이 상한: 긴 아이디로 메모리를 채우지 못하게 한다
  private static final int MAX_USERNAME_KEY_LENGTH = 100;
  // 로그에 남길 아이디 길이 상한
  private static final int MAX_LOGGED_USERNAME_LENGTH = 50;
  // login.html 이 이 파라미터로 잠김 안내를 띄운다
  public static final String LOCKED_REDIRECT_PATH = SecurityPaths.ADMIN_LOGIN + "?locked";

  private final SharedStateStore sharedStateStore;

  @Override
  protected boolean shouldNotFilter(HttpServletRequest request) {
    boolean isLoginSubmit = HttpMethod.POST.matches(request.getMethod())
      && SecurityPaths.ADMIN_LOGIN.equals(request.getServletPath());
    return !isLoginSubmit;
  }

  @Override
  protected void doFilterInternal(
    HttpServletRequest request,
    HttpServletResponse response,
    FilterChain filterChain
  ) throws ServletException, IOException {
    String normalizedUsername = normalizeUsername(request.getParameter(USERNAME_PARAMETER));
    boolean isAttemptAllowed = sharedStateStore.tryRecordInWindow(
      KEY_PREFIX + normalizedUsername, ATTEMPT_WINDOW, MAX_ATTEMPTS_PER_WINDOW, System.currentTimeMillis());

    if (!isAttemptAllowed) {
      log.warn("[admin login] rejected 302 : too many attempts, username={}", sanitizeForLog(normalizedUsername));
      response.sendRedirect(request.getContextPath() + LOCKED_REDIRECT_PATH);
      return;
    }
    filterChain.doFilter(request, response);
  }

  // 대소문자 변형으로 횟수를 피해 가지 못하게 소문자로 통일
  private String normalizeUsername(String rawUsername) {
    if (rawUsername == null) {
      return "";
    }
    String normalized = rawUsername.trim().toLowerCase(Locale.ROOT);
    return normalized.length() > MAX_USERNAME_KEY_LENGTH
      ? normalized.substring(0, MAX_USERNAME_KEY_LENGTH)
      : normalized;
  }

  // 로그용 값 정리 (제어문자·비ASCII > ?, 50자 제한)
  private String sanitizeForLog(String value) {
    String printable = value.replaceAll("[^\\x20-\\x7E]", "?");
    return printable.length() > MAX_LOGGED_USERNAME_LENGTH
      ? printable.substring(0, MAX_LOGGED_USERNAME_LENGTH)
      : printable;
  }
}
