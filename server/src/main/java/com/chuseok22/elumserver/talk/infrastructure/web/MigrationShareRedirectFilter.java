package com.chuseok22.elumserver.talk.infrastructure.web;

import com.chuseok22.elumserver.systemconfig.application.service.MigrationLock;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * 이전 잠금 중 공유 미리보기(/s/**)를 새 서버 같은 경로로 넘긴다 (#1053)
 * 밖에 퍼진 옛 도메인 링크가 잠긴 서버의 멈춘 내용 대신 최신 내용으로 열린다. 잠기지 않았거나 새 주소가 없으면 통과
 */
@RequiredArgsConstructor
public class MigrationShareRedirectFilter extends OncePerRequestFilter {

  private static final String QUERY_DELIMITER = "?";

  private final MigrationLock migrationLock;

  @Override
  protected void doFilterInternal(
    HttpServletRequest request, HttpServletResponse response, FilterChain chain
  ) throws ServletException, IOException {
    Optional<String> newServerBaseUrl = migrationLock.isLocked() ? migrationLock.newServerBaseUrl() : Optional.empty();
    if (newServerBaseUrl.isEmpty()) {
      chain.doFilter(request, response);
      return;
    }
    String query = request.getQueryString();
    String location = newServerBaseUrl.get() + request.getRequestURI() + (query == null ? "" : QUERY_DELIMITER + query);
    response.setStatus(HttpServletResponse.SC_FOUND);
    response.setHeader(HttpHeaders.LOCATION, location);
  }
}
