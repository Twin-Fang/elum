package com.chuseok22.elumserver.common.application.alert;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.infrastructure.properties.IncidentAlertProperties;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 5xx 급증 기준: 창 안 건수가 기준 미만이면 알림 없음 (#648)
 */
class ServerErrorSurgeDetectorTest {

  private static final Clock FIXED_CLOCK = Clock.fixed(Instant.parse("2026-10-29T05:00:00Z"), ZoneOffset.UTC);
  private static final int THRESHOLD = 3;
  private static final String PATH_TEMPLATE = "/api/routines/{routineId}";

  @Test
  @DisplayName("기준 건수 미만의 5xx 는 알림을 만들지 않는다 — 가끔 나는 오류 한두 건으로 밤중에 울리지 않게")
  void record_belowThreshold_returnsNoAlert() {
    ServerErrorSurgeDetector detector = new ServerErrorSurgeDetector(
      new IncidentAlertProperties("", "", THRESHOLD, 300, null, null), FIXED_CLOCK);

    assertThat(detector.record(500, "GET", PATH_TEMPLATE, "INTERNAL_SERVER_ERROR")).isEmpty();
    assertThat(detector.record(500, "GET", PATH_TEMPLATE, "INTERNAL_SERVER_ERROR")).isEmpty();
    // 기준에 닿는 순간에는 알림이 나와야 위 두 단언이 의미 있음
    assertThat(detector.record(500, "GET", PATH_TEMPLATE, "INTERNAL_SERVER_ERROR")).isPresent();
  }
}
