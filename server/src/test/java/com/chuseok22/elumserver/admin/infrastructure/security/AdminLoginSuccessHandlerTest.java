package com.chuseok22.elumserver.admin.infrastructure.security;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.infrastructure.store.InMemorySharedStateStore;
import jakarta.servlet.FilterChain;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;

/**
 * 관리자 로그인 성공 처리: 성공하면 그 아이디의 시도 기록이 지워져 실패만 쌓이는지 (#1102)
 * 깨지면: 테스트·이전 도구가 성공 로그인을 반복할 때 관리자 화면이 다시 잠긴다
 */
class AdminLoginSuccessHandlerTest {

  // AdminLoginAttemptFilter.MAX_ATTEMPTS_PER_WINDOW 와 같아야 한다
  private static final int MAX_ATTEMPTS = 50;
  private static final FilterChain PASSING_CHAIN = (request, response) -> { };

  private InMemorySharedStateStore sharedStateStore;
  private AdminLoginAttemptFilter filter;
  private AdminLoginSuccessHandler successHandler;

  @BeforeEach
  void setUp() {
    sharedStateStore = new InMemorySharedStateStore();
    filter = new AdminLoginAttemptFilter(sharedStateStore);
    successHandler = new AdminLoginSuccessHandler(sharedStateStore);
  }

  @Test
  @DisplayName("성공한 로그인은 한도에 쌓이지 않는다: 한도만큼 시도한 뒤 성공하면 다시 한도만큼 시도할 수 있다")
  void clearsAttemptsOnSuccess() throws Exception {
    for (int attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
      submitLogin("kimchi");
    }

    succeedLogin(" KimChi ");

    for (int attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
      assertThat(submitLogin("kimchi").getRedirectedUrl()).as("성공 뒤 시도 %d", attempt).isNull();
    }
    assertThat(submitLogin("kimchi").getRedirectedUrl()).isEqualTo("/admin/login?locked");
  }

  @Test
  @DisplayName("성공하면 대시보드로 이동한다")
  void redirectsToDashboard() throws Exception {
    MockHttpServletResponse response = succeedLogin("kimchi");

    assertThat(response.getRedirectedUrl()).isEqualTo("/admin/dashboard");
  }

  @Test
  @DisplayName("다른 아이디의 기록은 지우지 않는다")
  void keepsOtherUsernameAttempts() throws Exception {
    for (int attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
      submitLogin("attacker");
    }

    succeedLogin("kimchi");

    assertThat(submitLogin("attacker").getRedirectedUrl()).isEqualTo("/admin/login?locked");
  }

  private MockHttpServletResponse submitLogin(String username) throws Exception {
    MockHttpServletRequest request = loginRequest(username);
    MockHttpServletResponse response = new MockHttpServletResponse();
    filter.doFilter(request, response, PASSING_CHAIN);
    return response;
  }

  private MockHttpServletResponse succeedLogin(String username) throws Exception {
    MockHttpServletResponse response = new MockHttpServletResponse();
    successHandler.onAuthenticationSuccess(loginRequest(username), response,
      UsernamePasswordAuthenticationToken.authenticated(username.trim(), null, List.of()));
    return response;
  }

  private MockHttpServletRequest loginRequest(String username) {
    MockHttpServletRequest request = new MockHttpServletRequest("POST", "/admin/login");
    request.setServletPath("/admin/login");
    request.setParameter("username", username);
    return request;
  }
}
