package com.chuseok22.elumserver.common.infrastructure.alert;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;

/**
 * 5xx 급증 집계 대상 (#1222): 지표 수집 actuator 요청 제외, 사용자 요청은 그대로 셈
 */
class ServerErrorSurgeFilterActuatorExclusionTest {

  // 판정기·알림은 shouldNotFilter 판단에 쓰이지 않음
  private final ServerErrorSurgeFilter filter = new ServerErrorSurgeFilter(null, null);

  @Test
  @DisplayName("actuator 요청은 급증 집계에서 빠지고 API·헬스체크 요청은 그대로 센다")
  void excludesOnlyActuatorRequests() {
    assertThat(filter.shouldNotFilter(new MockHttpServletRequest("GET", "/actuator/prometheus"))).isTrue();
    assertThat(filter.shouldNotFilter(new MockHttpServletRequest("GET", "/api/routines"))).isFalse();
    assertThat(filter.shouldNotFilter(new MockHttpServletRequest("GET", "/healthz"))).isFalse();
  }
}
