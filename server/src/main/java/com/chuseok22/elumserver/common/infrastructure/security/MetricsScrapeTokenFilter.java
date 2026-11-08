package com.chuseok22.elumserver.common.infrastructure.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.List;
import org.springframework.http.HttpHeaders;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.context.SecurityContextHolderStrategy;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * 지표 수집기 인증 (#1222): Bearer 토큰 <-> 설정 토큰 고정 시간 비교 > 일치 시 수집기 권한, 그 외 401
 * 설정 토큰이 비면 항상 401 (fail-closed). 빈으로 두지 않음 (서블릿 필터로 한 번 더 등록되지 않게, actuator 체인에만 걺)
 */
public class MetricsScrapeTokenFilter extends OncePerRequestFilter {

  /// actuator 체인의 지표 경로 허용 권한
  public static final String METRICS_SCRAPER_AUTHORITY = "METRICS_SCRAPER";
  private static final String METRICS_SCRAPER_PRINCIPAL = "metrics-scraper";
  private static final String BEARER_PREFIX = "Bearer ";
  // 길이 차이도 드러나지 않게 양쪽을 같은 길이 해시로 바꿔 비교
  private static final String TOKEN_DIGEST_ALGORITHM = "SHA-256";

  private final byte[] configuredTokenDigest;
  private final boolean hasConfiguredToken;
  private final SecurityContextHolderStrategy securityContextHolderStrategy =
    SecurityContextHolder.getContextHolderStrategy();

  public MetricsScrapeTokenFilter(String configuredScrapeToken) {
    this.hasConfiguredToken = configuredScrapeToken != null && !configuredScrapeToken.isBlank();
    this.configuredTokenDigest = hasConfiguredToken ? digest(configuredScrapeToken.trim()) : new byte[0];
  }

  @Override
  protected void doFilterInternal(
    HttpServletRequest request, HttpServletResponse response, FilterChain chain
  ) throws ServletException, IOException {
    // sendError 대신 setStatus: /error 재진입(요청 로그 2줄)을 만들지 않음
    if (!isScrapeTokenMatched(request.getHeader(HttpHeaders.AUTHORIZATION))) {
      response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
      return;
    }
    SecurityContext securityContext = securityContextHolderStrategy.createEmptyContext();
    securityContext.setAuthentication(UsernamePasswordAuthenticationToken.authenticated(
      METRICS_SCRAPER_PRINCIPAL, null, List.of(new SimpleGrantedAuthority(METRICS_SCRAPER_AUTHORITY))));
    securityContextHolderStrategy.setContext(securityContext);
    chain.doFilter(request, response);
  }

  // 설정 토큰 없음·헤더 없음·Bearer 아님·불일치 > false
  private boolean isScrapeTokenMatched(String authorizationHeader) {
    if (!hasConfiguredToken || authorizationHeader == null || !authorizationHeader.startsWith(BEARER_PREFIX)) {
      return false;
    }
    String presentedToken = authorizationHeader.substring(BEARER_PREFIX.length()).trim();
    return !presentedToken.isEmpty() && MessageDigest.isEqual(configuredTokenDigest, digest(presentedToken));
  }

  private static byte[] digest(String token) {
    try {
      return MessageDigest.getInstance(TOKEN_DIGEST_ALGORITHM).digest(token.getBytes(StandardCharsets.UTF_8));
    } catch (NoSuchAlgorithmException e) {
      // JDK 기본 제공 알고리즘이라 실제로는 오지 않음
      throw new IllegalStateException(TOKEN_DIGEST_ALGORITHM + " unavailable", e);
    }
  }
}
