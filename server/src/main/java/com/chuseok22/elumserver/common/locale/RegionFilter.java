package com.chuseok22.elumserver.common.locale;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * {@code X-Elum-Region} 을 읽어 요청 범위의 {@link CurrentRegion} 에 담는다 (다국어 #526).
 *
 * <p>{@link AcceptLanguageFilter} 와 같은 패턴이다. 보안 체인(기본 -100)보다 앞에 두어 보안 필터가 쓰는 응답에서도 국가를 알 수 있고,
 * 요청이 끝나면 예외가 나도 비워 스레드 재사용으로 다음 요청에 국가가 새지 않게 한다.
 *
 * <p>참고: OncePerRequestFilter 는 기본적으로 에러 디스패치(/error)를 건너뛴다. 에러 디스패치 처리는 에러 문구 번역 작업에서 다룬다.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 11)
public class RegionFilter extends OncePerRequestFilter {

  /** 비동기 재진입에서도 지역을 다시 심는다(스레드가 바뀌므로). */
  @Override
  protected boolean shouldNotFilterAsyncDispatch() {
    return false;
  }

  @Override
  protected void doFilterInternal(
    HttpServletRequest request, HttpServletResponse response, FilterChain chain
  ) throws ServletException, IOException {
    CurrentRegion.set(CurrentRegion.parse(request.getHeader(CurrentRegion.HEADER)));
    try {
      chain.doFilter(request, response);
    } finally {
      CurrentRegion.clear();
    }
  }
}
