package com.chuseok22.elumserver.common.infrastructure.jwt;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.http.MediaType;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

@Component
public class JwtAuthenticationEntryPoint implements AuthenticationEntryPoint {

  private final ObjectMapper objectMapper = new ObjectMapper();

  @Override
  public void commence(
    HttpServletRequest request,
    HttpServletResponse response,
    AuthenticationException authException
  ) throws IOException {
    // 토큰 누락/무효/만료를 모두 포괄하는 401이므로 로그인 실패 전용 코드(INVALID_CREDENTIALS)가 아닌
    // INVALID_TOKEN을 사용한다 — 클라이언트가 "비밀번호 오류"로 오인하지 않도록 구분한다.
    ErrorCode errorCode = ErrorCode.INVALID_TOKEN;
    ErrorResponse errorResponse = new ErrorResponse(errorCode, errorCode.getMessage());

    response.setStatus(errorCode.getStatus().value());
    response.setContentType(MediaType.APPLICATION_JSON_VALUE);
    response.setCharacterEncoding("UTF-8");
    response.getWriter().write(objectMapper.writeValueAsString(errorResponse));
  }
}
