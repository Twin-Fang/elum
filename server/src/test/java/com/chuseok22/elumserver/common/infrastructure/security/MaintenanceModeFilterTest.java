package com.chuseok22.elumserver.common.infrastructure.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

/**
 * 점검 모드가 서버에서 API를 막는다 (이슈 #279 QA).
 *
 * <p>전에는 점검 중에도 쓰기 요청이 200으로 저장됐다.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class MaintenanceModeFilterTest {

  @Mock
  private SystemConfigService systemConfigService;

  private MockHttpServletResponse run(String method, String path) throws Exception {
    MockHttpServletRequest request = new MockHttpServletRequest(method, path);
    MockHttpServletResponse response = new MockHttpServletResponse();
    MockFilterChain chain = new MockFilterChain();
    new MaintenanceModeFilter(systemConfigService).doFilter(request, response, chain);
    // 체인이 불렸으면 통과, 아니면 막힌 것
    response.setHeader("X-Passed", String.valueOf(chain.getRequest() != null));
    return response;
  }

  private void maintenance(boolean on) {
    when(systemConfigService.getBoolean(ConfigKey.MAINTENANCE_MODE)).thenReturn(on);
    when(systemConfigService.getString(ConfigKey.MAINTENANCE_MESSAGE)).thenReturn("오늘 밤 10시까지 점검해요");
  }

  @Test
  @DisplayName("점검 중에는 쓰기 요청을 503으로 막고 관리자가 적은 안내를 준다")
  void maintenance_blocksWrites() throws Exception {
    maintenance(true);
    MockHttpServletResponse response = run("POST", "/api/member/consents");

    assertThat(response.getStatus()).isEqualTo(503);
    assertThat(response.getHeader("X-Passed")).isEqualTo("false");
    assertThat(response.getContentAsString()).contains("MAINTENANCE_MODE").contains("오늘 밤 10시까지 점검해요");
  }

  @Test
  @DisplayName("점검 중에는 조회도 막는다 — 앱이 503을 받아 점검 화면으로 간다")
  void maintenance_blocksReads() throws Exception {
    maintenance(true);
    assertThat(run("GET", "/api/member/me").getStatus()).isEqualTo(503);
  }

  @ParameterizedTest
  @ValueSource(strings = {"/api/app/status", "/api/consents/documents", "/api/auth/refresh"})
  @DisplayName("점검 중에도 상태 확인·약관 읽기·토큰 갱신은 연다")
  void maintenance_keepsOpenPaths(String path) throws Exception {
    maintenance(true);
    MockHttpServletResponse response = run(path.equals("/api/auth/refresh") ? "POST" : "GET", path);
    assertThat(response.getHeader("X-Passed")).isEqualTo("true");
  }

  @ParameterizedTest
  @ValueSource(strings = {"/api/auth/login", "/api/auth/signup"})
  @DisplayName("점검 중에는 로그인·가입도 막는다 — 계정이 새로 생기는 쓰기다")
  void maintenance_blocksLogin(String path) throws Exception {
    maintenance(true);
    assertThat(run("POST", path).getStatus()).isEqualTo(503);
  }

  @ParameterizedTest
  @ValueSource(strings = {"/api/app/notices", "/api/app/notices/abc/image"})
  @DisplayName("점검 중에는 공지도 막는다 — 앱이 점검 화면만 띄우므로 공지가 나갈 자리가 없다 (#370 N19)")
  void maintenance_blocksNotices(String path) throws Exception {
    maintenance(true);
    assertThat(run("GET", path).getStatus()).isEqualTo(503);
  }

  @Test
  @DisplayName("점검이 아니면 그대로 통과시킨다")
  void normal_passes() throws Exception {
    maintenance(false);
    assertThat(run("POST", "/api/member/consents").getHeader("X-Passed")).isEqualTo("true");
  }

  @Test
  @DisplayName("설정을 읽지 못하면 막지 않는다 — 설정 하나가 흔들렸다고 전체가 503이 되면 안 된다")
  void configFailure_passes() throws Exception {
    when(systemConfigService.getBoolean(ConfigKey.MAINTENANCE_MODE)).thenThrow(new IllegalStateException("DB"));
    assertThat(run("GET", "/api/member/me").getHeader("X-Passed")).isEqualTo("true");
  }
}
