package com.chuseok22.elumserver.common.infrastructure.logging;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.UUID;
import java.util.regex.Pattern;
import org.slf4j.MDC;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * 요청 추적 id: 요청마다 id 부여 > MDC(requestId) + 응답 헤더 X-Request-Id > 끝나면 MDC 정리 (#656)
 * 로그 줄(logback-spring.xml)·에러 응답 본문(ErrorResponse)·관리자 로그 검색이 같은 id 로 만남
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class RequestIdFilter extends OncePerRequestFilter {

  /// 요청·응답 헤더 이름 (chuseok22 logging 라이브러리 기본 상관 헤더와 같음)
  public static final String REQUEST_ID_HEADER = "X-Request-Id";
  /// MDC: 요청 id. chuseok22 logging 라이브러리 기본 mdcKey 와 같아 @LogMonitoring 덤프도 이 값을 씀
  public static final String MDC_REQUEST_ID_KEY = "requestId";
  /// MDC: 인증된 회원 id (JwtAuthenticationFilter 가 넣음, 정리는 이 필터)
  public static final String MDC_MEMBER_ID_KEY = "memberId";

  /// 요청 헤더로 받은 id 허용 형식: 영숫자·하이픈 1~64자 (그 밖은 로그 주입 위험이라 버리고 새로 만듦)
  private static final Pattern SAFE_INBOUND_REQUEST_ID = Pattern.compile("^[A-Za-z0-9-]{1,64}$");
  /// 새로 만드는 id 길이 (UUID 16진수 앞 12자)
  private static final int GENERATED_REQUEST_ID_LENGTH = 12;
  /// 같은 요청의 오류·비동기 재진입에서 id 를 이어 쓰기 위한 요청 속성
  private static final String REQUEST_ID_ATTRIBUTE = RequestIdFilter.class.getName() + ".requestId";

  @Override
  protected boolean shouldNotFilterAsyncDispatch() {
    return false;
  }

  @Override
  protected boolean shouldNotFilterErrorDispatch() {
    return false;
  }

  @Override
  protected void doFilterInternal(
    HttpServletRequest request, HttpServletResponse response, FilterChain chain
  ) throws ServletException, IOException {
    String requestId = resolveRequestId(request);
    request.setAttribute(REQUEST_ID_ATTRIBUTE, requestId);
    MDC.put(MDC_REQUEST_ID_KEY, requestId);
    response.setHeader(REQUEST_ID_HEADER, requestId);
    try {
      chain.doFilter(request, response);
    } finally {
      // 스레드 재사용 시 다음 요청에 남지 않게 (성공·실패 공통)
      MDC.remove(MDC_REQUEST_ID_KEY);
      MDC.remove(MDC_MEMBER_ID_KEY);
    }
  }

  /// 지금 요청의 id (요청 밖이면 null)
  public static String currentRequestId() {
    return MDC.get(MDC_REQUEST_ID_KEY);
  }

  // 같은 요청의 재진입 > 이어 씀, 안전한 요청 헤더 > 그대로, 그 외 > 새로 만듦
  private static String resolveRequestId(HttpServletRequest request) {
    Object previousRequestId = request.getAttribute(REQUEST_ID_ATTRIBUTE);
    if (previousRequestId instanceof String requestId) {
      return requestId;
    }
    String inboundRequestId = request.getHeader(REQUEST_ID_HEADER);
    if (isSafeInboundRequestId(inboundRequestId)) {
      return inboundRequestId;
    }
    return UUID.randomUUID().toString().replace("-", "").substring(0, GENERATED_REQUEST_ID_LENGTH);
  }

  static boolean isSafeInboundRequestId(String inboundRequestId) {
    return inboundRequestId != null && SAFE_INBOUND_REQUEST_ID.matcher(inboundRequestId).matches();
  }
}
