package com.chuseok22.elumserver.common.infrastructure.logging;

import ch.qos.logback.classic.Level;
import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.turbo.TurboFilter;
import ch.qos.logback.core.spi.FilterReply;
import org.slf4j.MDC;
import org.slf4j.Marker;

/**
 * MDC 에 {@link #MDC_KEY} 가 걸린 요청 안에서는 WARN 미만 로그를 버린다 (logback-spring.xml).
 *
 * <p>관리자 로그 화면은 2초마다 tail 을 부른다. 운영은 DispatcherServlet 이 DEBUG 라 요청마다 두 줄이
 * 찍혀, 로그를 보는 동안 로그가 그 조회 기록으로 덮인다. 오류(WARN 이상)는 그대로 남긴다.
 */
public class QuietLogTurboFilter extends TurboFilter {

  public static final String MDC_KEY = "elum.quietLog";

  @Override
  public FilterReply decide(Marker marker, Logger logger, Level level, String format, Object[] params, Throwable t) {
    if (level != null && !level.isGreaterOrEqual(Level.WARN) && MDC.get(MDC_KEY) != null) {
      return FilterReply.DENY;
    }
    return FilterReply.NEUTRAL;
  }
}
