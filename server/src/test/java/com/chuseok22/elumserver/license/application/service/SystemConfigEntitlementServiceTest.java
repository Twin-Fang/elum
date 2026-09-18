package com.chuseok22.elumserver.license.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.core.SubscriptionStatus;
import com.chuseok22.elumserver.license.infrastructure.entity.Subscription;
import com.chuseok22.elumserver.license.infrastructure.repository.SubscriptionRepository;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.LocalDateTime;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class SystemConfigEntitlementServiceTest {

  private static final String MEMBER_ID = "m1";

  @Mock
  private SubscriptionRepository subscriptionRepository;

  @Mock
  private SystemConfigService systemConfigService;

  @InjectMocks
  private SystemConfigEntitlementService entitlementService;

  private Subscription subscription(PlanType plan, SubscriptionStatus status, LocalDateTime expiresAt) {
    Subscription s = new Subscription();
    s.setPlan(plan);
    s.setStatus(status);
    s.setExpiresAt(expiresAt);
    return s;
  }

  // --- 플랜 판정 ---

  @Test
  @DisplayName("구독 행이 없으면 Free다 — 기존 회원을 옮기지 않아도 되는 이유")
  void noSubscription_isFree() {
    when(subscriptionRepository.findByMemberId(MEMBER_ID)).thenReturn(Optional.empty());

    assertThat(entitlementService.planOf(MEMBER_ID)).isEqualTo(PlanType.FREE);
  }

  @Test
  @DisplayName("이용 중인 Pro는 Pro다")
  void activePro_isPro() {
    when(subscriptionRepository.findByMemberId(MEMBER_ID))
      .thenReturn(Optional.of(subscription(PlanType.PRO, SubscriptionStatus.ACTIVE, null)));

    assertThat(entitlementService.planOf(MEMBER_ID)).isEqualTo(PlanType.PRO);
  }

  @Test
  @DisplayName("만료된 Pro는 Free로 떨어진다")
  void expiredPro_isFree() {
    when(subscriptionRepository.findByMemberId(MEMBER_ID)).thenReturn(Optional.of(
      subscription(PlanType.PRO, SubscriptionStatus.ACTIVE, LocalDateTime.now().minusDays(1))));

    assertThat(entitlementService.planOf(MEMBER_ID)).isEqualTo(PlanType.FREE);
  }

  @Test
  @DisplayName("구독 조회가 실패해도 막지 않고 Free로 계속한다")
  void repositoryFailure_isFree() {
    when(subscriptionRepository.findByMemberId(MEMBER_ID))
      .thenThrow(new RuntimeException("DB 장애"));

    assertThat(entitlementService.planOf(MEMBER_ID)).isEqualTo(PlanType.FREE);
  }

  @Test
  @DisplayName("회원 식별자가 없으면 조회 없이 Free다")
  void blankMemberId_isFreeWithoutQuery() {
    assertThat(entitlementService.planOf(null)).isEqualTo(PlanType.FREE);
    assertThat(entitlementService.planOf(" ")).isEqualTo(PlanType.FREE);
  }

  // --- 권한 조회 ---

  @Test
  @DisplayName("플랜에 맞는 설정 키를 읽는다")
  void readsConfigKeyOfCurrentPlan() {
    when(subscriptionRepository.findByMemberId(MEMBER_ID))
      .thenReturn(Optional.of(subscription(PlanType.PRO, SubscriptionStatus.ACTIVE, null)));
    when(systemConfigService.getBoolean(ConfigKey.PRO_AI_IMAGE_GENERATION)).thenReturn(true);

    assertThat(entitlementService.isAllowed(MEMBER_ID, Entitlement.AI_IMAGE_GENERATION)).isTrue();
  }

  // --- 한도 판정 ---

  @Test
  @DisplayName("-1은 무제한이라 사용량이 아무리 많아도 통과한다")
  void unlimited_alwaysWithin() {
    when(subscriptionRepository.findByMemberId(MEMBER_ID)).thenReturn(Optional.empty());
    when(systemConfigService.getInt(any())).thenReturn(Entitlement.UNLIMITED);

    assertThat(entitlementService.isWithinLimit(
      MEMBER_ID, Entitlement.ROUTINE_CREATE_PER_WEEK, 9_999)).isTrue();
  }

  @Test
  @DisplayName("한도 미만이면 통과하고 도달하면 막는다")
  void limitBoundary() {
    when(subscriptionRepository.findByMemberId(MEMBER_ID)).thenReturn(Optional.empty());
    when(systemConfigService.getInt(any())).thenReturn(5);

    assertThat(entitlementService.isWithinLimit(
      MEMBER_ID, Entitlement.ROUTINE_CREATE_PER_WEEK, 4)).isTrue();
    assertThat(entitlementService.isWithinLimit(
      MEMBER_ID, Entitlement.ROUTINE_CREATE_PER_WEEK, 5)).isFalse();
  }

  @Test
  @DisplayName("0이면 한 번도 못 쓴다")
  void zeroLimit_blocksEverything() {
    when(subscriptionRepository.findByMemberId(MEMBER_ID)).thenReturn(Optional.empty());
    when(systemConfigService.getInt(any())).thenReturn(0);

    assertThat(entitlementService.isWithinLimit(
      MEMBER_ID, Entitlement.ROUTINE_CREATE_PER_WEEK, 0)).isFalse();
  }

  @Test
  @DisplayName("-1이 아닌 이상한 음수가 들어와도 사용자를 막지 않는다")
  void invalidNegativeLimit_passesThrough() {
    when(subscriptionRepository.findByMemberId(MEMBER_ID)).thenReturn(Optional.empty());
    when(systemConfigService.getInt(any())).thenReturn(-7);

    assertThat(entitlementService.isWithinLimit(
      MEMBER_ID, Entitlement.ROUTINE_CREATE_PER_WEEK, 100)).isTrue();
  }

  // --- 스냅샷 ---

  @Test
  @DisplayName("스냅샷은 현재 플랜의 값으로 채워진다")
  void snapshot_usesCurrentPlanValues() {
    when(subscriptionRepository.findByMemberId(MEMBER_ID)).thenReturn(Optional.empty());
    lenient().when(systemConfigService.getBoolean(any())).thenReturn(false);
    lenient().when(systemConfigService.getInt(any())).thenReturn(3);
    when(systemConfigService.getBoolean(ConfigKey.FREE_AI_IMAGE_GENERATION)).thenReturn(true);

    EntitlementSnapshot snapshot = entitlementService.snapshot(MEMBER_ID);

    assertThat(snapshot.plan()).isEqualTo(PlanType.FREE);
    assertThat(snapshot.aiImageGeneration()).isTrue();
    assertThat(snapshot.adsRemoved()).isFalse();
    assertThat(snapshot.routineCreatePerWeek()).isEqualTo(3);
  }
}
