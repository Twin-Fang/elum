package com.chuseok22.elumserver.common.application.alert;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 같은 알림 반복 억제: 쿨다운 키별 마지막 발송 시각 > 간격 안이면 거절
 * 재시작하면 비어 첫 알림은 다시 나감
 */
final class IncidentAlertCooldown {

  // 키가 이 개수를 넘으면 오래된 키 정리 (날짜별 키가 쌓이지 않게)
  private static final int PRUNE_KEY_COUNT = 64;
  // 정리 기준: 마지막 발송 후 경과 시간 (가장 긴 종류 쿨다운 24시간과 같음)
  private static final Duration PRUNE_AFTER = Duration.ofHours(24);

  private final Map<String, Instant> lastSentAtByKey = new ConcurrentHashMap<>();

  /** 보내도 되면 발송 시각을 기록하고 true, 쿨다운 안이면 false */
  boolean tryAcquire(String cooldownKey, Duration cooldown, Instant now) {
    pruneIfLarge(now);
    boolean[] isAcquired = {false};
    lastSentAtByKey.compute(cooldownKey, (key, lastSentAt) -> {
      if (lastSentAt != null && now.isBefore(lastSentAt.plus(cooldown))) {
        return lastSentAt;
      }
      isAcquired[0] = true;
      return now;
    });
    return isAcquired[0];
  }

  private void pruneIfLarge(Instant now) {
    if (lastSentAtByKey.size() <= PRUNE_KEY_COUNT) {
      return;
    }
    Instant cutoff = now.minus(PRUNE_AFTER);
    lastSentAtByKey.values().removeIf(lastSentAt -> lastSentAt.isBefore(cutoff));
  }
}
