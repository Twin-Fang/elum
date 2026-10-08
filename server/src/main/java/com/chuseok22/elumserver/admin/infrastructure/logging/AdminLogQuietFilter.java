package com.chuseok22.elumserver.admin.infrastructure.logging;

import com.chuseok22.elumserver.common.infrastructure.logging.QuietLogTurboFilter;
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
 * 관리자 로그 화면의 조회(GET)는 요청 처리 동안 WARN 미만 로그를 남기지 않게 표시한다({@link QuietLogTurboFilter}).
 * 삭제·레벨 변경은 누가 무엇을 바꿨는지 남아야 하므로 GET 만 조용히 한다.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class AdminLogQuietFilter extends OncePerRequestFilter {

  static final String QUIET_PATH_PREFIX = "/admin/logs/api/";

  @Override
  protected boolean shouldNotFilter(HttpServletRequest request) {
    return !"GET".equals(request.getMethod()) || !request.getRequestURI().startsWith(QUIET_PATH_PREFIX);
  }

  @Override
  protected void doFilterInternal(
    HttpServletRequest request, HttpServletResponse response, FilterChain chain
  ) throws ServletException, IOException {
    MDC.put(QuietLogTurboFilter.MDC_KEY, "true");
    try {
      chain.doFilter(request, response);
    } finally {
      MDC.remove(QuietLogTurboFilter.MDC_KEY);
    }
  }
}
