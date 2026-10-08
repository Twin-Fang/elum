package com.chuseok22.elumserver.common.infrastructure.logging;

import ch.qos.logback.classic.Level;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.classic.spi.IThrowableProxy;
import ch.qos.logback.core.AppenderBase;
import java.time.Instant;

/** logback-spring.xml 의 RECENT_ERRORS. ERROR 만 RecentErrorStore 에 넘긴다. */
public class RecentErrorAppender extends AppenderBase<ILoggingEvent> {

  private static final int MAX_MESSAGE_LENGTH = 300;

  @Override
  protected void append(ILoggingEvent event) {
    if (!event.getLevel().isGreaterOrEqual(Level.ERROR)) {
      return;
    }
    IThrowableProxy throwable = event.getThrowableProxy();
    RecentErrorStore.global().record(new RecentErrorStore.RecentError(
      Instant.ofEpochMilli(event.getTimeStamp()),
      event.getLoggerName(),
      firstLine(event.getFormattedMessage()),
      throwable == null ? null : throwable.getClassName()
    ));
  }

  // 목록에는 요약만 둔다. 전체 내용은 elum-error.log 에 있다.
  static String firstLine(String message) {
    if (message == null) {
      return "";
    }
    int newline = message.indexOf('\n');
    String line = newline < 0 ? message : message.substring(0, newline);
    return line.length() > MAX_MESSAGE_LENGTH ? line.substring(0, MAX_MESSAGE_LENGTH) + "…" : line;
  }
}
