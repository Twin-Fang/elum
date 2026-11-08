package com.chuseok22.elumserver.common.infrastructure.logging;

import com.chuseok22.elumserver.common.infrastructure.constant.SecurityPaths;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.slf4j.MDC;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * actuator 요청 처리 동안 WARN 미만 로그 숨김 표시 ({@link QuietLogTurboFilter}, #1222)
 * Prometheus 가 30초마다 수집 > DispatcherServlet DEBUG 2줄이 서버 로그를 덮지 않게. 오류(WARN 이상)는 남김
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class MetricsScrapeLogQuietFilter extends OncePerRequestFilter {

  @Override
  protected boolean shouldNotFilter(HttpServletRequest request) {
    return !request.getRequestURI().startsWith(SecurityPaths.ACTUATOR_PATH_PREFIX);
  }

  @Override
  protected void doFilterInternal(
    HttpServletRequest request, HttpServletResponse response, FilterChain chain
  ) throws ServletException, IOException {
    MDC.put(QuietLogTurboFilter.MDC_KEY, "true");
    try {
      chain.doFilter(request, response);
    } finally {
      // 스레드 재사용 시 다음 요청까지 숨기지 않게 (성공·실패 공통)
      MDC.remove(QuietLogTurboFilter.MDC_KEY);
    }
  }
}
