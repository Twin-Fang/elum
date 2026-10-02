package com.chuseok22.elumserver.common.locale;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * {@code Accept-Language} 를 읽어 요청 범위의 {@link CurrentLocale} 에 담는다 (다국어 #526).
 *
 * <p><b>Spring Security 체인보다 앞에 둔다.</b> 체인의 기본 순서는 -100 이다. 뒤에 두면 점검 모드(503)·토큰 오류(401)처럼
 * 보안 필터가 직접 쓰는 오류 응답이 요청 언어를 모른다. 헤더가 없으면 KO 라 이미 배포된 앱의 응답은 그대로다.
 *
 * <p>에러 디스패치(/error)는 건너뛴다: ErrorController 구현과 ErrorAttributes 커스텀이 없어 /error 본문은 기본
 * BasicErrorController(HTTP 상태 문구, 영어 고정)가 만들고 ErrorMessages 를 거치지 않는다(#526 확인). 그래서 언어 선택과
 * 무관하다. /error 본문을 ErrorMessages 로 만들게 되면 shouldNotFilterErrorDispatch 를 false 로 바꿔야 한다.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 10)
public class AcceptLanguageFilter extends OncePerRequestFilter {

  /** 비동기 재진입에서도 언어를 다시 심는다(스레드가 바뀌므로). */
  @Override
  protected boolean shouldNotFilterAsyncDispatch() {
    return false;
  }

  @Override
  protected void doFilterInternal(
    HttpServletRequest request, HttpServletResponse response, FilterChain chain
  ) throws ServletException, IOException {
    CurrentLocale.set(AppLocale.fromAcceptLanguage(request.getHeader(HttpHeaders.ACCEPT_LANGUAGE)));
    try {
      chain.doFilter(request, response);
    } finally {
      CurrentLocale.clear();
    }
  }
}
