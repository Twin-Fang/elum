package com.chuseok22.elumserver.license.infrastructure.entity;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.core.SubscriptionStatus;
import java.time.LocalDateTime;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class SubscriptionTest {

  private static final LocalDateTime NOW = LocalDateTime.of(2026, 9, 18, 12, 0);

  private Subscription pro(SubscriptionStatus status, LocalDateTime expiresAt) {
    Subscription subscription = new Subscription();
    subscription.setPlan(PlanType.PRO);
    subscription.setStatus(status);
    subscription.setExpiresAt(expiresAt);
    return subscription;
  }

  @Test
  @DisplayName("이용 중이고 만료일이 없으면 Pro다")
  void activeWithoutExpiry_isPro() {
    assertThat(pro(SubscriptionStatus.ACTIVE, null).effectivePlan(NOW)).isEqualTo(PlanType.PRO);
  }

  @Test
  @DisplayName("만료일이 아직 남았으면 Pro다")
  void activeBeforeExpiry_isPro() {
    assertThat(pro(SubscriptionStatus.ACTIVE, NOW.plusDays(1)).effectivePlan(NOW))
      .isEqualTo(PlanType.PRO);
  }

  @Test
  @DisplayName("만료일이 지나면 배치 없이도 Free로 떨어진다")
  void expired_fallsBackToFree() {
    assertThat(pro(SubscriptionStatus.ACTIVE, NOW.minusSeconds(1)).effectivePlan(NOW))
      .isEqualTo(PlanType.FREE);
  }

  @Test
  @DisplayName("해지·만료 상태면 기간이 남아 있어도 Free다")
  void notActive_isFree() {
    assertThat(pro(SubscriptionStatus.CANCELLED, NOW.plusYears(1)).effectivePlan(NOW))
      .isEqualTo(PlanType.FREE);
    assertThat(pro(SubscriptionStatus.EXPIRED, NOW.plusYears(1)).effectivePlan(NOW))
      .isEqualTo(PlanType.FREE);
  }
}
