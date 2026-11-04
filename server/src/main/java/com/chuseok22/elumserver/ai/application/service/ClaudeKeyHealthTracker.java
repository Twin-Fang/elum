package com.chuseok22.elumserver.ai.application.service;

import com.chuseok22.elumserver.ai.core.AiFailureKind;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicReference;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * Claude 키별 상태 (메모리): 마지막 성공·실패 시각, 실패 원인, 쉬는 시간(cooldown), 마지막으로 응답한 키 (#1083)
 * 실패한 키는 5분 뒤로 미룸 > 쉬는 키만 남으면 그래도 순서대로 시도 (키 상태 때문에 일과 생성이 멈추지 않게)
 * 서버 재시작·배포 시 비워짐 (호출 기록 ai_call_log 에 키 별명이 남아 이력은 그쪽에서 봄)
 */
@Component
@RequiredArgsConstructor
public class ClaudeKeyHealthTracker {

  // 실패한 키를 뒤로 미루는 시간
  static final Duration FAILURE_COOLDOWN = Duration.ofMinutes(5);

  private final Clock clock;
  private final Map<String, KeyHealth> healthByKeyId = new ConcurrentHashMap<>();
  private final AtomicReference<String> lastServedKeyId = new AtomicReference<>();

  public void onSuccess(String keyId) {
    LocalDateTime now = LocalDateTime.now(clock);
    healthByKeyId.compute(keyId, (id, before) -> before == null
      ? new KeyHealth(now, null, null, null)
      : new KeyHealth(now, before.lastFailureAt(), before.lastFailureKind(), null));
    lastServedKeyId.set(keyId);
  }

  public void onFailure(String keyId, AiFailureKind failureKind) {
    LocalDateTime now = LocalDateTime.now(clock);
    healthByKeyId.compute(keyId, (id, before) -> new KeyHealth(
      before == null ? null : before.lastSuccessAt(), now, failureKind, now.plus(FAILURE_COOLDOWN)));
  }

  /// 쉬는 중인가 (마지막 실패 후 5분 안, 그 뒤 성공 없음)
  public boolean isCoolingDown(String keyId) {
    KeyHealth health = healthByKeyId.get(keyId);
    return health != null && health.cooldownUntil() != null
      && LocalDateTime.now(clock).isBefore(health.cooldownUntil());
  }

  public Optional<KeyHealth> healthOf(String keyId) {
    return Optional.ofNullable(healthByKeyId.get(keyId));
  }

  /// 마지막으로 응답한 키 id (재시작 후 첫 호출 전이면 빈 값)
  public Optional<String> lastServedKeyId() {
    return Optional.ofNullable(lastServedKeyId.get());
  }

  /**
   * 키 하나의 상태
   *
   * @param cooldownUntil 이 시각까지 뒤로 미룸 (성공하면 null)
   */
  public record KeyHealth(
    LocalDateTime lastSuccessAt, LocalDateTime lastFailureAt, AiFailureKind lastFailureKind,
    LocalDateTime cooldownUntil
  ) {

  }
}
