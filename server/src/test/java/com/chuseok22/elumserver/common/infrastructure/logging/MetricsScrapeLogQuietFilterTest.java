package com.chuseok22.elumserver.common.infrastructure.logging;

import static org.assertj.core.api.Assertions.assertThat;

import jakarta.servlet.ServletException;
import java.io.IOException;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.slf4j.MDC;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

/**
 * 지표 수집 요청 로그 숨김 (#1222): actuator 요청 처리 동안만 표시, 끝나면 지움
 */
class MetricsScrapeLogQuietFilterTest {

  private final MetricsScrapeLogQuietFilter filter = new MetricsScrapeLogQuietFilter();

  @Test
  @DisplayName("actuator 요청 동안에만 로그 숨김 표시가 걸리고, 끝나면 지운다")
  void marksOnlyActuatorRequests() throws ServletException, IOException {
    assertThat(isMarkedDuring("/actuator/prometheus")).isTrue();
    assertThat(isMarkedDuring("/actuator/health")).isTrue();
    assertThat(isMarkedDuring("/healthz")).isFalse();
    assertThat(isMarkedDuring("/api/routines")).isFalse();
    assertThat(MDC.get(QuietLogTurboFilter.MDC_KEY)).isNull();
  }

  private boolean isMarkedDuring(String uri) throws ServletException, IOException {
    AtomicReference<String> markSeenByChain = new AtomicReference<>();
    filter.doFilter(new MockHttpServletRequest("GET", uri), new MockHttpServletResponse(),
      (request, response) -> markSeenByChain.set(MDC.get(QuietLogTurboFilter.MDC_KEY)));
    return markSeenByChain.get() != null;
  }
}
