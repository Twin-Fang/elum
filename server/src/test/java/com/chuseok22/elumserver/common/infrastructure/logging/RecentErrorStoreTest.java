package com.chuseok22.elumserver.common.infrastructure.logging;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.infrastructure.logging.RecentErrorStore.RecentError;
import com.chuseok22.elumserver.common.infrastructure.logging.RecentErrorStore.Snapshot;
import java.time.Duration;
import java.time.Instant;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class RecentErrorStoreTest {

  private static final Instant NOW = Instant.parse("2026-10-08T03:00:00Z");

  @Test
  @DisplayName("최근 목록은 50건까지만, 최신이 앞에 온다")
  void keepsLatestFifty() {
    RecentErrorStore store = new RecentErrorStore(NOW.minus(Duration.ofDays(1)));
    for (int i = 0; i < 60; i++) {
      store.record(new RecentError(NOW.minusSeconds(60 - i), "logger", "m" + i, null));
    }

    Snapshot snapshot = store.snapshot(NOW);

    assertThat(snapshot.recent()).hasSize(RecentErrorStore.MAX_RECENT);
    assertThat(snapshot.recent().get(0).message()).isEqualTo("m59");
    assertThat(snapshot.last24h()).isEqualTo(60);
  }

  @Test
  @DisplayName("24시간이 지난 오류는 건수에서 빠진다")
  void countsOnlyLast24Hours() {
    RecentErrorStore store = new RecentErrorStore(NOW.minus(Duration.ofDays(3)));
    store.record(new RecentError(NOW.minus(Duration.ofHours(25)), "a", "old", null));
    store.record(new RecentError(NOW.minus(Duration.ofHours(1)), "b", "new", "java.lang.IllegalStateException"));

    Snapshot snapshot = store.snapshot(NOW);

    assertThat(snapshot.last24h()).isEqualTo(1);
    assertThat(snapshot.recent()).hasSize(2);
  }

  @Test
  @DisplayName("메시지는 첫 줄만, 길면 자른다")
  void firstLineOnly() {
    assertThat(RecentErrorAppender.firstLine("첫 줄\n둘째 줄")).isEqualTo("첫 줄");
    assertThat(RecentErrorAppender.firstLine(null)).isEmpty();
    assertThat(RecentErrorAppender.firstLine("x".repeat(400))).hasSize(301);
  }
}
