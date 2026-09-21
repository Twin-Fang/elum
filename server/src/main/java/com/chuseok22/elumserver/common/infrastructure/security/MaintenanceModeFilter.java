package com.chuseok22.elumserver.common.infrastructure.security;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.common.infrastructure.constant.SecurityPaths;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
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
 * 점검 중에는 API를 막는다 (이슈 #279).
 *
 * <p>전에는 점검 모드가 <b>알려주기만</b> 했다. 앱은 시작할 때 한 번만 확인하므로, 점검을
 * 켜기 전에 앱을 연 사람은 점검 중에도 평소처럼 데이터를 바꿨다. 로컬에서 점검을 켠 채
 * 동의 기록 API를 부르니 200으로 저장됐다 (#279 QA). 점검 모드를 켜는 이유가 "DB를 손으로
 * 고치는 동안 데이터를 지키는 것"이라면 서버가 막아야 한다.
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

  /** 관리자가 적은 안내 문구를 그대로 준다. 앱이 점검 화면에 띄운다. */
  private String message() {
    try {
      String configured = systemConfigService.getString(ConfigKey.MAINTENANCE_MESSAGE);
      return configured == null || configured.isBlank()
        ? ErrorCode.MAINTENANCE_MODE.getMessage() : configured;
    } catch (RuntimeException e) {
      return ErrorCode.MAINTENANCE_MODE.getMessage();
    }
  }
}
