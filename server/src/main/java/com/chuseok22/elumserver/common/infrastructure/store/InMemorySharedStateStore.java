package com.chuseok22.elumserver.common.infrastructure.store;

import java.time.Duration;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * 서버 한 대를 전제한 구현. <b>지금 동작을 그대로 유지한다.</b>
 *
 * <p>여러 대로 늘리면 각 서버가 자기 메모리만 보므로 제한이 서버 수만큼 헐거워진다.
 * 그때는 이 클래스 자리에 공유 저장소(Redis 등) 구현체를 넣는다 — 이 인터페이스를
 * 쓰는 쪽은 한 줄도 바뀌지 않는다.
 *
 * <p>방치하면 열쇠 수만큼 메모리가 무한히 쌓이므로, 접근할 때마다 만료된 것을 치운다.
 *
 * <p><b>구현체는 설정으로 고른다.</b> {@code elum.store.shared-state} 값이 없거나
 * {@code memory}면 이것이 쓰인다. 공유 저장소 구현체를 추가할 때는 같은 자리에 다른
 * 값을 조건으로 달면 되고, 그러면 <b>등록되는 것은 언제나 하나</b>라 서버가 뜨지 않는
 * 사고가 나지 않는다.
 */
@Component
@ConditionalOnProperty(name = "elum.store.shared-state", havingValue = "memory", matchIfMissing = true)
public class InMemorySharedStateStore implements SharedStateStore {

  /// 열쇠 수가 이 값을 넘으면 만료된 것을 먼저 치운다. 매번 전체를 훑지 않기 위한 문턱이다.
  private static final int EVICT_THRESHOLD = 10_000;

  /// 열쇠 → 만료 시각. 만료 시각을 함께 두어 열쇠마다 다른 수명을 지원한다.
  private final Map<String, Long> expiresAt = new ConcurrentHashMap<>();

  /// 열쇠 → 창 안에 기록된 시각들.
  private final Map<String, Deque<Long>> windowHits = new ConcurrentHashMap<>();

  @Override
  public synchronized boolean firstSeen(String key, Duration ttl, long nowMillis) {
    if (expiresAt.size() > EVICT_THRESHOLD) {
      expiresAt.entrySet().removeIf(entry -> entry.getValue() <= nowMillis);
    }
    Long expiry = expiresAt.get(key);
    if (expiry != null && expiry > nowMillis) {
      return false;
    }
    expiresAt.put(key, nowMillis + ttl.toMillis());
    return true;
  }

  @Override
  public boolean tryRecordInWindow(String key, Duration window, int max, long nowMillis) {
    long cutoff = nowMillis - window.toMillis();

    if (windowHits.size() > EVICT_THRESHOLD) {
      windowHits.entrySet().removeIf(entry -> {
        Deque<Long> hits = entry.getValue();
        synchronized (hits) {
          return hits.isEmpty() || hits.peekLast() <= cutoff;
        }
      });
    }

    Deque<Long> hits = windowHits.computeIfAbsent(key, k -> new ArrayDeque<>());
    synchronized (hits) {
      while (!hits.isEmpty() && hits.peekFirst() <= cutoff) {
        hits.pollFirst();
      }
      if (hits.size() >= max) {
        return false;
      }
      hits.addLast(nowMillis);
      return true;
    }
  }
}
