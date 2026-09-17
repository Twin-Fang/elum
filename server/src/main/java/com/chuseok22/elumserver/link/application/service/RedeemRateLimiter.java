package com.chuseok22.elumserver.link.application.service;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 연결 암호 넣기의 호출자별 속도 제한 (이슈 #200).
 *
 * <p><b>암호별 실패 횟수만으로는 막히지 않는다.</b> 그 카운터는 이미 존재하는 암호를
 * 두드릴 때만 올라간다. 무작위로 찍는 쪽은 매번 없는 값에 걸려 아무 흔적도 남기지 않고
 * 계속 시도할 수 있다. 그래서 호출자 단위로도 센다.
 *
 * <p>인스턴스 메모리에 둔다 — 지금은 서버가 한 대라 충분하다. 여러 대로 늘리면 이 값이
 * 인스턴스마다 갈리므로 공유 저장소(Redis 등)로 옮겨야 한다.
 */
@Slf4j
@Component
public class RedeemRateLimiter {

  /** 사람이 받아적어 넣는 속도로는 넉넉하다. */
  private static final int MAX_PER_WINDOW = 10;

  private static final Duration WINDOW = Duration.ofMinutes(1);

  /** 방치하면 IP 수만큼 무한히 쌓인다. 이 수를 넘으면 오래된 것부터 비운다. */
  private static final int MAX_TRACKED_CALLERS = 10_000;

  private final Map<String, Deque<Instant>> attempts = new ConcurrentHashMap<>();

  /** 시도해도 되면 true. 창 안에서 한도를 넘었으면 false. */
  public boolean tryAcquire(String caller) {
    Instant now = Instant.now();
    Instant cutoff = now.minus(WINDOW);

    if (attempts.size() > MAX_TRACKED_CALLERS) {
      attempts.entrySet().removeIf(e -> {
        Deque<Instant> q = e.getValue();
        synchronized (q) {
          return q.isEmpty() || q.peekLast().isBefore(cutoff);
        }
      });
    }

    Deque<Instant> queue = attempts.computeIfAbsent(caller, k -> new ArrayDeque<>());
    synchronized (queue) {
      while (!queue.isEmpty() && queue.peekFirst().isBefore(cutoff)) {
        queue.pollFirst();
      }
      if (queue.size() >= MAX_PER_WINDOW) {
        log.warn("연결 암호 시도가 너무 잦습니다: caller={}, 창 안 시도={}", caller, queue.size());
        return false;
      }
      queue.addLast(now);
      return true;
    }
  }
}
