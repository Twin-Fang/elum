package com.chuseok22.elumserver.common.infrastructure.security;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Component;

// 재전송 방지용 nonce 저장소. 단일 인스턴스 데모 기준 인메모리로 충분하다.
// 각 nonce의 최초 수신 시각을 기억하고, TTL(10분)이 지난 항목은 새 요청이 올 때 청소한다.
@Component
public class NonceStore {

  private static final long TTL_MILLIS = 10 * 60 * 1000L; // timestamp 허용오차(±5분)보다 넉넉히

  private final Map<String, Long> seen = new ConcurrentHashMap<>();

  // 처음 보는 nonce면 기억하고 true, 이미 유효 범위 내에서 본 적 있으면 false.
  public synchronized boolean checkAndRemember(String nonce, long nowMillis) {
    evictExpired(nowMillis);
    Long prev = seen.get(nonce);
    if (prev != null && nowMillis - prev < TTL_MILLIS) {
      return false; // 재사용
    }
    seen.put(nonce, nowMillis);
    return true;
  }

  private void evictExpired(long nowMillis) {
    seen.entrySet().removeIf(e -> nowMillis - e.getValue() >= TTL_MILLIS);
  }
}
