package com.chuseok22.elumserver.link.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.stream.IntStream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 호출자별 속도 제한 (이슈 #200).
 *
 * <p>암호별 실패 횟수는 **이미 존재하는 암호**를 두드릴 때만 올라간다. 무작위로 찍는 쪽은
 * 매번 없는 값에 걸려 흔적을 남기지 않으므로, 여기서 막지 않으면 아무도 막지 않는다.
 */
class RedeemRateLimiterTest {

  @Test
  @DisplayName("분당 10회까지 통과하고 11번째부터 막는다")
  void limitsPerCaller() {
    RedeemRateLimiter limiter = new RedeemRateLimiter();

    long passed = IntStream.range(0, 20)
      .filter(i -> limiter.tryAcquire("1.2.3.4"))
      .count();

    assertThat(passed).isEqualTo(10);
  }

  @Test
  @DisplayName("호출자가 다르면 서로 영향을 주지 않는다 — 한 사람이 남을 막지 못한다")
  void isolatesCallers() {
    RedeemRateLimiter limiter = new RedeemRateLimiter();

    IntStream.range(0, 15).forEach(i -> limiter.tryAcquire("1.2.3.4"));

    assertThat(limiter.tryAcquire("5.6.7.8")).isTrue();
  }
}
