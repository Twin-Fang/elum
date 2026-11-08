package com.chuseok22.elumserver.common.infrastructure.security;

import static org.assertj.core.api.Assertions.assertThat;

import jakarta.servlet.http.HttpServletResponse;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;

/**
 * 수집기 토큰 필터 (#1222): 일치 시에만 다음 필터 + 수집기 권한, 그 외 401 후 중단
 */
class MetricsScrapeTokenFilterTest {

  private static final String SCRAPE_TOKEN = "scrape-token-value";
  private static final String PROMETHEUS_PATH = "/actuator/prometheus";

  @AfterEach
  void clearSecurityContext() {
    SecurityContextHolder.clearContext();
  }

  @Test
  @DisplayName("맞는 토큰이면 다음 필터로 넘기고 수집기 권한을 심는다")
  void matchedToken_passesWithScraperAuthority() throws Exception {
    AtomicReference<Authentication> authenticationSeenByChain = new AtomicReference<>();
    MockHttpServletResponse response = new MockHttpServletResponse();

    new MetricsScrapeTokenFilter(SCRAPE_TOKEN).doFilter(requestWithAuthorization("Bearer " + SCRAPE_TOKEN), response,
      (request, chainResponse) -> authenticationSeenByChain.set(SecurityContextHolder.getContext().getAuthentication()));

    assertThat(response.getStatus()).isEqualTo(HttpServletResponse.SC_OK);
    assertThat(authenticationSeenByChain.get()).isNotNull();
    assertThat(authenticationSeenByChain.get().isAuthenticated()).isTrue();
    assertThat(authenticationSeenByChain.get().getAuthorities()).extracting(GrantedAuthority::getAuthority)
      .containsExactly(MetricsScrapeTokenFilter.METRICS_SCRAPER_AUTHORITY);
  }

  @Test
  @DisplayName("토큰 헤더가 없으면 401 이고 다음 필터로 넘기지 않는다")
  void missingToken_isUnauthorized() throws Exception {
    assertUnauthorizedWithoutChain(new MetricsScrapeTokenFilter(SCRAPE_TOKEN), null);
  }

  @Test
  @DisplayName("틀린 토큰·Bearer 아닌 형식·빈 Bearer 는 401 이다")
  void wrongToken_isUnauthorized() throws Exception {
    MetricsScrapeTokenFilter filter = new MetricsScrapeTokenFilter(SCRAPE_TOKEN);
    assertUnauthorizedWithoutChain(filter, "Bearer wrong-token");
    assertUnauthorizedWithoutChain(filter, "Bearer " + SCRAPE_TOKEN + "x");
    assertUnauthorizedWithoutChain(filter, SCRAPE_TOKEN);
    assertUnauthorizedWithoutChain(filter, "Basic " + SCRAPE_TOKEN);
    assertUnauthorizedWithoutChain(filter, "Bearer ");
  }

  @Test
  @DisplayName("설정 토큰이 비어 있으면 어떤 요청도 401 이다 (빈 Bearer 포함)")
  void emptyConfiguredToken_isAlwaysUnauthorized() throws Exception {
    for (String configuredToken : new String[]{null, "", "   "}) {
      MetricsScrapeTokenFilter filter = new MetricsScrapeTokenFilter(configuredToken);
      assertUnauthorizedWithoutChain(filter, null);
      assertUnauthorizedWithoutChain(filter, "Bearer ");
      assertUnauthorizedWithoutChain(filter, "Bearer " + SCRAPE_TOKEN);
    }
  }

  // 401 + 다음 필터 미호출 + 인증 없음
  private static void assertUnauthorizedWithoutChain(MetricsScrapeTokenFilter filter, String authorizationHeader)
    throws Exception {
    AtomicReference<Boolean> isChainCalled = new AtomicReference<>(false);
    MockHttpServletResponse response = new MockHttpServletResponse();

    filter.doFilter(requestWithAuthorization(authorizationHeader), response,
      (request, chainResponse) -> isChainCalled.set(true));

    assertThat(response.getStatus()).as("Authorization=%s", authorizationHeader)
      .isEqualTo(HttpServletResponse.SC_UNAUTHORIZED);
    assertThat(isChainCalled.get()).as("Authorization=%s", authorizationHeader).isFalse();
    assertThat(SecurityContextHolder.getContext().getAuthentication()).isNull();
  }

  private static MockHttpServletRequest requestWithAuthorization(String authorizationHeader) {
    MockHttpServletRequest request = new MockHttpServletRequest("GET", PROMETHEUS_PATH);
    if (authorizationHeader != null) {
      request.addHeader(HttpHeaders.AUTHORIZATION, authorizationHeader);
    }
    return request;
  }
}
