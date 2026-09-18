package com.chuseok22.elumserver.common.infrastructure.store;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Duration;
import java.util.stream.IntStream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

class InMemorySharedStateStoreTest {

  private static final long T0 = 1_700_000_000_000L;

  private final InMemorySharedStateStore store = new InMemorySharedStateStore();

  @Nested
  @DisplayName("처음인가")
  class FirstSeen {

    private static final Duration TTL = Duration.ofMinutes(10);

    @Test
    @DisplayName("처음 보면 통과하고 다시 오면 막는다")
    void firstPassesRestBlocked() {
      assertThat(store.firstSeen("a", TTL, T0)).isTrue();
      assertThat(store.firstSeen("a", TTL, T0)).isFalse();
      assertThat(store.firstSeen("b", TTL, T0)).isTrue();
    }

    @Test
    @DisplayName("기간이 지나면 다시 통과한다")
    void afterTtl_passesAgain() {
      assertThat(store.firstSeen("a", TTL, T0)).isTrue();
      assertThat(store.firstSeen("a", TTL, T0 + TTL.toMillis() - 1)).isFalse();
      assertThat(store.firstSeen("a", TTL, T0 + TTL.toMillis())).isTrue();
    }

    @Test
    @DisplayName("열쇠마다 수명이 달라도 서로 간섭하지 않는다")
    void independentTtlPerKey() {
      store.firstSeen("짧은것", Duration.ofSeconds(30), T0);
      store.firstSeen("긴것", Duration.ofMinutes(10), T0);

      long after1Min = T0 + Duration.ofMinutes(1).toMillis();

      assertThat(store.firstSeen("짧은것", Duration.ofSeconds(30), after1Min)).isTrue();
      assertThat(store.firstSeen("긴것", Duration.ofMinutes(10), after1Min)).isFalse();
    }
  }

  @Nested
  @DisplayName("몇 번째인가")
  class Window {

    private static final Duration WINDOW = Duration.ofMinutes(1);
    private static final int MAX = 10;

    private boolean record(long at) {
      return store.tryRecordInWindow("caller", WINDOW, MAX, at);
    }

    @Test
    @DisplayName("한도까지 통과하고 그 뒤로 막는다")
    void allowsUpToMax() {
      long passed = IntStream.range(0, 20).filter(i -> record(T0)).count();

      assertThat(passed).isEqualTo(MAX);
    }

    @Test
    @DisplayName("막힌 시도는 창에 남기지 않는다 — 계속 두드려도 창이 제때 열린다")
    void rejectedAttemptsDoNotExtendWindow() {
      IntStream.range(0, MAX).forEach(i -> record(T0));
      // 막힌 뒤에도 계속 두드린다
      IntStream.range(0, 50).forEach(i -> record(T0 + 1000));

      // 처음 기록들이 창을 벗어나는 시점에는 다시 통과해야 한다
      assertThat(record(T0 + WINDOW.toMillis())).isTrue();
    }

    @Test
    @DisplayName("창이 지나면 회복된다")
    void recoversAfterWindow() {
      IntStream.range(0, MAX).forEach(i -> record(T0));

      assertThat(record(T0)).isFalse();
      assertThat(record(T0 + WINDOW.toMillis())).isTrue();
    }

    @Test
    @DisplayName("호출자가 다르면 서로 막지 않는다")
    void isolatesKeys() {
      IntStream.range(0, 20).forEach(i -> store.tryRecordInWindow("a", WINDOW, MAX, T0));

      assertThat(store.tryRecordInWindow("b", WINDOW, MAX, T0)).isTrue();
    }
  }
}
