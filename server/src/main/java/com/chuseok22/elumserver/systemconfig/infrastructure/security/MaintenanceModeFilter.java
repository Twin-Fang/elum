package com.chuseok22.elumserver.systemconfig.infrastructure.security;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.common.infrastructure.constant.SecurityPaths;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorMessages;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * 점검 중에는 API를 막는다.
 *
 * <p>점검 모드가 알려주기만 하면 앱은 시작할 때 한 번만 확인하므로, 점검을 켜기 전에 앱을 연 사람은
 * 점검 중에도 데이터를 바꾼다. 점검 모드는 "DB를 손으로 고치는 동안 데이터를 지키는 것"이라 서버가 막아야 한다.
 *
 * <p><b>JWT 필터보다 앞에 둔다.</b> 뒤에 두면 만료된 토큰이 먼저 401을 받고, 앱은 토큰
 * 갱신에 나선다. 앞에 두면 503 하나로 끝나고 앱은 점검 화면으로 간다.
 *
 * <p>열어 두는 곳은 셋이다.
 * <ul>
 *   <li>앱 상태 확인 — 막으면 앱이 점검 사실을 받을 길이 없다</li>
 *   <li>약관 읽기 — 읽기 전용이고 가입 화면이 떠 있을 수 있다</li>
 *   <li>토큰 갱신 — 막으면 점검 한 번에 로그아웃될 수 있다</li>
 * </ul>
 */
@Slf4j
@RequiredArgsConstructor
public class MaintenanceModeFilter extends OncePerRequestFilter {

  private static final Set<String> OPEN_PATHS = Set.of(
    SecurityPaths.API_APP_STATUS,
    SecurityPaths.API_CONSENT_DOCUMENTS,
    SecurityPaths.API_AUTH_REFRESH
  );

  private final SystemConfigService systemConfigService;
  private final ObjectMapper objectMapper = new ObjectMapper();
  private final ErrorMessages messages = ErrorMessages.standard();

  @Override
  protected boolean shouldNotFilter(HttpServletRequest request) {
    return OPEN_PATHS.contains(request.getRequestURI());
  }

  @Override
  protected void doFilterInternal(
    HttpServletRequest request, HttpServletResponse response, FilterChain chain
  ) throws ServletException, IOException {
    if (!isMaintenance()) {
      chain.doFilter(request, response);
      return;
    }
    log.info("[점검 모드] 요청을 막았습니다 — {} {}", request.getMethod(), request.getRequestURI());
    ErrorCode code = ErrorCode.MAINTENANCE_MODE;
    response.setStatus(code.getStatus().value());
    response.setContentType(MediaType.APPLICATION_JSON_VALUE);
    response.setCharacterEncoding("UTF-8");
    response.getWriter().write(objectMapper.writeValueAsString(new ErrorResponse(code, message())));
  }

  /**
   * 설정을 읽지 못하면 막지 않는다. 설정 저장소 하나가 흔들렸다고 모든 API가 503이 되면
   * 점검이 아닌데도 서비스가 멈춘다.
   */
  private boolean isMaintenance() {
    try {
      return systemConfigService.getBoolean(ConfigKey.MAINTENANCE_MODE);
    } catch (RuntimeException e) {
      log.warn("[점검 모드] 설정을 읽지 못해 막지 않고 통과시킵니다", e);
      return false;
    }
  }

  /**
   * 점검 안내. 관리자가 직접 쓴 문구(한국어)는 그대로 준다. 기본 문구를 그대로 둔 경우만 요청 언어로 바꾼다 —
   * 기본 문구는 ErrorCode.MAINTENANCE_MODE 의 ko 문구와 같은 글자라 ko 응답은 이전과 같다.
   */
  private String message() {
    ErrorCode code = ErrorCode.MAINTENANCE_MODE;
    try {
      String configured = systemConfigService.getString(ConfigKey.MAINTENANCE_MESSAGE);
      boolean untouched = configured == null || configured.isBlank()
        || configured.equals(ConfigKey.MAINTENANCE_MESSAGE.getDefaultValue());
      return untouched ? messages.of(code) : configured;
    } catch (RuntimeException e) {
      return messages.of(code);
    }
  }
}
