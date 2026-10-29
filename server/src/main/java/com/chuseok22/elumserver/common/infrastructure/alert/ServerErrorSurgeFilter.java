package com.chuseok22.elumserver.common.infrastructure.alert;

import com.chuseok22.elumserver.common.application.alert.IncidentAlertService;
import com.chuseok22.elumserver.common.application.alert.ServerErrorSurgeDetector;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.context.request.RequestAttributes;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.servlet.HandlerMapping;
import org.springframework.web.util.DisconnectedClientHelper;

/**
 * 응답 상태 > 5xx 급증 판정기 전달 (#648)
 * 넘기는 값 4개: 상태 코드, 메서드, 매핑 경로 템플릿, 에러 코드 (실제 주소·쿼리·본문은 안 넘김)
 * 등록은 IncidentAlertFilterConfig (@Component 면 @WebMvcTest 조각이 주워 의존 빈 없이 실패)
 * 오류 재진입(ERROR dispatch)은 두 번 세지 않음
 */
@Slf4j
@RequiredArgsConstructor
public class ServerErrorSurgeFilter extends OncePerRequestFilter {

  /// 요청 속성: GlobalExceptionHandler 가 고른 에러 코드 이름
  static final String ERROR_CODE_ATTRIBUTE = ServerErrorSurgeFilter.class.getName() + ".errorCode";
  // 매핑 전에 실패한 요청 (보안 필터 등) > 실제 주소 대신 고정 문구
  private static final String UNKNOWN_PATH_TEMPLATE = "(매핑 전)";
  // 체인 밖으로 예외가 나가면 컨테이너가 500 으로 응답
  private static final int UNHANDLED_EXCEPTION_STATUS = HttpServletResponse.SC_INTERNAL_SERVER_ERROR;

  private final ServerErrorSurgeDetector serverErrorSurgeDetector;
  private final IncidentAlertService incidentAlertService;

  /** 지금 요청의 에러 코드 표시 (요청 밖이면 무시) */
  public static void markErrorCode(ErrorCode errorCode) {
    RequestAttributes requestAttributes = RequestContextHolder.getRequestAttributes();
    if (requestAttributes == null || errorCode == null) {
      return;
    }
    requestAttributes.setAttribute(ERROR_CODE_ATTRIBUTE, errorCode.name(), RequestAttributes.SCOPE_REQUEST);
  }

  @Override
  protected void doFilterInternal(
    HttpServletRequest request, HttpServletResponse response, FilterChain chain
  ) throws ServletException, IOException {
    try {
      chain.doFilter(request, response);
    } catch (IOException | ServletException | RuntimeException e) {
      // 앱이 연결을 끊은 경우는 서버 오류가 아님 > 세지 않음 (예외는 그대로 위로 전달)
      if (!DisconnectedClientHelper.isClientDisconnectedException(e)) {
        recordQuietly(request, UNHANDLED_EXCEPTION_STATUS);
      }
      throw e;
    }
    recordQuietly(request, response.getStatus());
  }

  // 집계·알림 실패가 응답을 바꾸지 않게 로그만
  private void recordQuietly(HttpServletRequest request, int status) {
    try {
      serverErrorSurgeDetector
        .record(status, request.getMethod(), toPathTemplate(request), toErrorCode(request))
        .ifPresent(incidentAlertService::notify);
    } catch (RuntimeException e) {
      log.warn("[incident alert] server error record failed : status={}, error={}", status,
        e.getClass().getSimpleName());
    }
  }

  private static String toPathTemplate(HttpServletRequest request) {
    Object pattern = request.getAttribute(HandlerMapping.BEST_MATCHING_PATTERN_ATTRIBUTE);
    return pattern == null ? UNKNOWN_PATH_TEMPLATE : pattern.toString();
  }

  private static String toErrorCode(HttpServletRequest request) {
    Object errorCode = request.getAttribute(ERROR_CODE_ATTRIBUTE);
    return errorCode == null ? null : errorCode.toString();
  }
}
