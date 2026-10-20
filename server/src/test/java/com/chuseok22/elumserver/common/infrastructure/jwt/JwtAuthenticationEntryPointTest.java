package com.chuseok22.elumserver.common.infrastructure.jwt;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.BadCredentialsException;

/**
 * 인증 실패 401 응답 계약 고정: 상태 코드, Content-Type, 인코딩, JSON 바이트
 * 깨지면 앱이 INVALID_TOKEN 으로 토큰 갱신·로그아웃 분기를 못 함
 */
class JwtAuthenticationEntryPointTest {

  @Test
  @DisplayName("인증 실패는 401 과 INVALID_TOKEN JSON 을 UTF-8 로 쓴다")
  void commence_writesInvalidTokenJson() throws Exception {
    MockHttpServletResponse response = new MockHttpServletResponse();

    new JwtAuthenticationEntryPoint().commence(
      new MockHttpServletRequest("GET", "/api/member/me"), response, new BadCredentialsException("x"));

    assertThat(response.getStatus()).isEqualTo(401);
    assertThat(response.getContentType()).isEqualTo("application/json;charset=UTF-8");
    assertThat(response.getCharacterEncoding()).isEqualTo("UTF-8");
    assertThat(response.getContentAsByteArray()).isEqualTo(
      "{\"errorCode\":\"INVALID_TOKEN\",\"errorMessage\":\"유효하지 않은 토큰이에요.\"}"
        .getBytes(StandardCharsets.UTF_8));
  }
}
