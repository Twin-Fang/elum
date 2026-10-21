package com.chuseok22.elumserver.admin.infrastructure.security;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.infrastructure.store.InMemorySharedStateStore;
import jakarta.servlet.FilterChain;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

/**
 * 관리자 로그인 시도 제한: 같은 아이디로 6번째 시도부터 인증 없이 잠김 안내로 돌려보내는지
 * 막힌 시도가 뒤 필터(비밀번호 대조)까지 가면 무차별 대입 방어가 아니므로 통과 횟수를 센다.
 */
class AdminLoginAttemptFilterTest {

  private AdminLoginAttemptFilter filter;
  private AtomicInteger passedToNextFilterCount;
  private FilterChain countingChain;

  @BeforeEach
  void setUp() {
    filter = new AdminLoginAttemptFilter(new InMemorySharedStateStore());
    passedToNextFilterCount = new AtomicInteger();
    countingChain = (request, response) -> passedToNextFilterCount.incrementAndGet();
  }

  @Test
  @DisplayName("같은 아이디로 5번까지는 통과하고 6번째는 잠김 안내로 돌려보낸다")
  void blocksSixthAttemptOfSameUsername() throws Exception {
    for (int attempt = 1; attempt <= 5; attempt++) {
      MockHttpServletResponse response = submitLogin("kimchi");
      assertThat(response.getRedirectedUrl()).as("시도 %d", attempt).isNull();
    }

    MockHttpServletResponse sixth = submitLogin("kimchi");

    assertThat(sixth.getRedirectedUrl()).isEqualTo("/admin/login?locked");
    assertThat(passedToNextFilterCount.get()).isEqualTo(5);
  }

  @Test
  @DisplayName("대소문자를 바꿔도 같은 아이디로 센다")
  void countsCaseVariantsTogether() throws Exception {
    for (String username : new String[] {"kimchi", "KIMCHI", "Kimchi", " kimchi ", "kImChI"}) {
      submitLogin(username);
    }

    MockHttpServletResponse locked = submitLogin("KiMcHi");

    assertThat(locked.getRedirectedUrl()).isEqualTo("/admin/login?locked");
  }

  @Test
  @DisplayName("다른 아이디는 영향받지 않는다")
  void doesNotAffectOtherUsername() throws Exception {
    for (int attempt = 0; attempt < 6; attempt++) {
      submitLogin("kimchi");
    }

    MockHttpServletResponse otherUser = submitLogin("someone-else");

    assertThat(otherUser.getRedirectedUrl()).isNull();
  }

  @Test
  @DisplayName("로그인 제출이 아닌 요청은 세지 않는다 (로그인 화면 조회, 다른 관리자 경로)")
  void ignoresNonLoginSubmitRequests() throws Exception {
    for (int attempt = 0; attempt < 10; attempt++) {
      MockHttpServletRequest loginPage = new MockHttpServletRequest("GET", "/admin/login");
      loginPage.setServletPath("/admin/login");
      filter.doFilter(loginPage, new MockHttpServletResponse(), countingChain);

      MockHttpServletRequest dashboard = new MockHttpServletRequest("POST", "/admin/members");
      dashboard.setServletPath("/admin/members");
      dashboard.setParameter("username", "kimchi");
      filter.doFilter(dashboard, new MockHttpServletResponse(), countingChain);
    }

    assertThat(submitLogin("kimchi").getRedirectedUrl()).isNull();
  }

  private MockHttpServletResponse submitLogin(String username) throws Exception {
    MockHttpServletRequest request = new MockHttpServletRequest("POST", "/admin/login");
    request.setServletPath("/admin/login");
    request.setParameter("username", username);
    MockHttpServletResponse response = new MockHttpServletResponse();
    filter.doFilter(request, response, countingChain);
    return response;
  }
}
