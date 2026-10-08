package com.chuseok22.elumserver.admin.infrastructure.logging;

import static org.assertj.core.api.Assertions.assertThat;

import ch.qos.logback.classic.Level;
import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.LoggerContext;
import ch.qos.logback.core.spi.FilterReply;
import com.chuseok22.elumserver.common.infrastructure.logging.QuietLogTurboFilter;
import jakarta.servlet.ServletException;
import java.io.IOException;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.slf4j.MDC;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

class AdminLogQuietFilterTest {

  private final AdminLogQuietFilter filter = new AdminLogQuietFilter();
  private final QuietLogTurboFilter turbo = new QuietLogTurboFilter();
  private final Logger logger = new LoggerContext().getLogger("test");

  @Test
  @DisplayName("로그 조회 GET 동안에만 표시가 걸리고, 끝나면 지운다")
  void marksOnlyLogApiGets() throws ServletException, IOException {
    assertThat(markedDuring("GET", "/admin/logs/api/tail")).isTrue();
    assertThat(markedDuring("DELETE", "/admin/logs/api/files")).isFalse();
    assertThat(markedDuring("GET", "/admin/logs")).isFalse();
    assertThat(markedDuring("GET", "/api/routines")).isFalse();
    assertThat(MDC.get(QuietLogTurboFilter.MDC_KEY)).isNull();
  }

  @Test
  @DisplayName("표시가 걸린 요청은 WARN 미만만 버리고 오류는 남긴다")
  void dropsBelowWarnOnly() {
    MDC.put(QuietLogTurboFilter.MDC_KEY, "true");
    try {
      assertThat(turbo.decide(null, logger, Level.DEBUG, "x", null, null)).isEqualTo(FilterReply.DENY);
      assertThat(turbo.decide(null, logger, Level.INFO, "x", null, null)).isEqualTo(FilterReply.DENY);
      assertThat(turbo.decide(null, logger, Level.WARN, "x", null, null)).isEqualTo(FilterReply.NEUTRAL);
      assertThat(turbo.decide(null, logger, Level.ERROR, "x", null, null)).isEqualTo(FilterReply.NEUTRAL);
    } finally {
      MDC.remove(QuietLogTurboFilter.MDC_KEY);
    }
    assertThat(turbo.decide(null, logger, Level.DEBUG, "x", null, null)).isEqualTo(FilterReply.NEUTRAL);
  }

  private boolean markedDuring(String method, String uri) throws ServletException, IOException {
    MockHttpServletRequest request = new MockHttpServletRequest(method, uri);
    AtomicReference<String> seen = new AtomicReference<>();
    filter.doFilter(request, new MockHttpServletResponse(), (req, res) -> seen.set(MDC.get(QuietLogTurboFilter.MDC_KEY)));
    return seen.get() != null;
  }
}
