package com.chuseok22.elumserver.member.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.infrastructure.store.InMemorySharedStateStore;
import java.util.stream.IntStream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 초대 코드의 계정별 시도 제한 (이슈 #361, E10).
 *
 * <p>코드 하나의 실패 횟수는 존재하는 코드를 두드릴 때만 오른다. 무작위로 찍는 쪽은 매번 없는 값에 걸려 흔적이
 * 없으므로, 여기서 막지 않으면 여섯 글자 7억 가지를 막는 것이 없다.
 */
class ProfileInviteRateLimiterTest {

  @Test
  @DisplayName("E10 입력은 계정당 10분에 10번까지 통과하고 11번째부터 막는다")
  void redeem_limitsPerAccount() {
    ProfileInviteRateLimiter limiter = new ProfileInviteRateLimiter(new InMemorySharedStateStore());

    long passed = IntStream.range(0, 30).filter(i -> limiter.tryRedeem("m1")).count();

    assertThat(passed).isEqualTo(ProfileInviteRateLimiter.REDEEM_MAX_PER_WINDOW).isEqualTo(10);
  }

  @Test
  @DisplayName("E10 계정이 다르면 서로 영향을 주지 않는다 — 한 사람이 남을 막지 못한다")
  void redeem_isolatesAccounts() {
    ProfileInviteRateLimiter limiter = new ProfileInviteRateLimiter(new InMemorySharedStateStore());

    IntStream.range(0, 15).forEach(i -> limiter.tryRedeem("m1"));

    assertThat(limiter.tryRedeem("m2")).isTrue();
  }

  @Test
  @DisplayName("발급과 입력은 따로 센다 — 코드를 몇 번 다시 만들었다고 입력이 막히지 않는다")
  void issueAndRedeem_areCountedSeparately() {
    ProfileInviteRateLimiter limiter = new ProfileInviteRateLimiter(new InMemorySharedStateStore());

    IntStream.range(0, 15).forEach(i -> limiter.tryIssue("m1"));

    assertThat(limiter.tryRedeem("m1")).isTrue();
  }

  @Test
  @DisplayName("발급은 계정당 10분에 10번까지다")
  void issue_limitsPerAccount() {
    ProfileInviteRateLimiter limiter = new ProfileInviteRateLimiter(new InMemorySharedStateStore());

    long passed = IntStream.range(0, 30).filter(i -> limiter.tryIssue("m1")).count();

    assertThat(passed).isEqualTo(ProfileInviteRateLimiter.ISSUE_MAX_PER_WINDOW);
  }
}
