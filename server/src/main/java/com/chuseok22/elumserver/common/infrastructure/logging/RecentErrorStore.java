package com.chuseok22.elumserver.common.infrastructure.logging;

import java.lang.management.ManagementFactory;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.List;

/**
 * 최근 ERROR 로그를 메모리에 모은다.
 * logback 은 Spring 컨텍스트보다 먼저 뜨므로 빈이 아니라 정적 저장소(global)에 쓴다.
 * 재시작하면 비므로 화면은 since(집계 시작 시각)를 함께 보여준다.
 */
public final class RecentErrorStore {

  static final int MAX_RECENT = 50;
  // 오류 폭주 시 메모리를 무한히 먹지 않게 24시간 집계용 시각도 상한을 둔다.
  static final int MAX_TIMESTAMPS = 10_000;
  static final Duration WINDOW = Duration.ofHours(24);

  // 클래스는 첫 ERROR 나 첫 조회 때 로드된다. 집계 시작은 그 시각이 아니라 JVM 시작 시각이다.
  private static final RecentErrorStore GLOBAL =
    new RecentErrorStore(Instant.ofEpochMilli(ManagementFactory.getRuntimeMXBean().getStartTime()));

  private final Instant since;
  private final Deque<RecentError> recent = new ArrayDeque<>();
  private final Deque<Instant> timestamps = new ArrayDeque<>();

  public RecentErrorStore(Instant since) {
    this.since = since;
  }

  public static RecentErrorStore global() {
    return GLOBAL;
  }

  public synchronized void record(RecentError error) {
    recent.addFirst(error);
    while (recent.size() > MAX_RECENT) {
      recent.pollLast();
    }
    timestamps.addLast(error.time());
    while (timestamps.size() > MAX_TIMESTAMPS) {
      timestamps.pollFirst();
    }
  }

  public synchronized Snapshot snapshot(Instant now) {
    Instant cutoff = now.minus(WINDOW);
    while (!timestamps.isEmpty() && timestamps.peekFirst().isBefore(cutoff)) {
      timestamps.pollFirst();
    }
    return new Snapshot(timestamps.size(), since, List.copyOf(recent));
  }

  public record RecentError(Instant time, String logger, String message, String exceptionClass) {
  }

  public record Snapshot(int last24h, Instant since, List<RecentError> recent) {
  }
}
