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
import com.chuseok22.elumserver.member.application.service.MemberSignupTimeService;
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

  @Mock
  private MemberSignupTimeService memberSignupTimeService;

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

  // --- 신규가입 PRO 이벤트 ---

  private void givenEvent(boolean isEnabled, String startAt, String endAt, int grantDays) {
    lenient().when(systemConfigService.getBoolean(ConfigKey.SIGNUP_PRO_EVENT_ENABLED)).thenReturn(isEnabled);
    lenient().when(systemConfigService.getString(ConfigKey.SIGNUP_PRO_EVENT_START_AT)).thenReturn(startAt);
    lenient().when(systemConfigService.getString(ConfigKey.SIGNUP_PRO_EVENT_END_AT)).thenReturn(endAt);
    lenient().when(systemConfigService.getInt(ConfigKey.SIGNUP_PRO_EVENT_GRANT_DAYS)).thenReturn(grantDays);
  }

  private void givenNoSubscriptionSignedUpAt(LocalDateTime signupAt) {
    when(subscriptionRepository.findByMemberId(MEMBER_ID)).thenReturn(Optional.empty());
    lenient().when(memberSignupTimeService.findSignupAt(MEMBER_ID)).thenReturn(Optional.ofNullable(signupAt));
  }

  @Test
  @DisplayName("이벤트가 꺼져 있으면 가입 기간 안이어도 Free다")
  void signupEvent_disabled_isFree() {
    givenEvent(false, "2026-01-01", "2099-01-01", 30);
    givenNoSubscriptionSignedUpAt(LocalDateTime.now());

    assertThat(entitlementService.planOf(MEMBER_ID)).isEqualTo(PlanType.FREE);
  }

  @Test
  @DisplayName("가입 기간 안에 가입했고 유지 일수 안이면 Pro다")
  void signupEvent_insideWindow_isPro() {
    givenEvent(true, "2026-01-01T00:00", "2099-01-01 00:00", 7);
    givenNoSubscriptionSignedUpAt(LocalDateTime.now().minusDays(1));

    assertThat(entitlementService.planOf(MEMBER_ID)).isEqualTo(PlanType.PRO);
  }

  @Test
  @DisplayName("가입 기간 밖(시작 전·종료 후)에 가입했으면 Free다")
  void signupEvent_outsideWindow_isFree() {
    givenEvent(true, "2026-01-01", "2026-02-01", 100000);
    givenNoSubscriptionSignedUpAt(LocalDateTime.of(2025, 12, 31, 23, 59));
    assertThat(entitlementService.planOf(MEMBER_ID)).isEqualTo(PlanType.FREE);

    givenNoSubscriptionSignedUpAt(LocalDateTime.of(2026, 2, 1, 0, 1));
    assertThat(entitlementService.planOf(MEMBER_ID)).isEqualTo(PlanType.FREE);
  }

  @Test
  @DisplayName("유지 일수가 지나면 Free로 돌아간다")
  void signupEvent_grantExpired_isFree() {
    givenEvent(true, "2026-01-01", "2099-01-01", 7);
    givenNoSubscriptionSignedUpAt(LocalDateTime.now().minusDays(8));

    assertThat(entitlementService.planOf(MEMBER_ID)).isEqualTo(PlanType.FREE);
  }

  @Test
  @DisplayName("구독 행이 있으면 이벤트와 무관하게 기존 판정 그대로다")
  void signupEvent_subscriptionRowWins() {
    givenEvent(true, "2026-01-01", "2099-01-01", 30);
    when(subscriptionRepository.findByMemberId(MEMBER_ID)).thenReturn(Optional.of(
      subscription(PlanType.PRO, SubscriptionStatus.ACTIVE, LocalDateTime.now().minusDays(1))));

    assertThat(entitlementService.planOf(MEMBER_ID)).isEqualTo(PlanType.FREE);
  }

  @Test
  @DisplayName("이벤트 설정 오류(날짜 형식·빈 기간·회원 조회 실패)는 Free로 폴백한다")
  void signupEvent_errors_fallBackToFree() {
    givenEvent(true, "어제", "2099-01-01", 30);
    givenNoSubscriptionSignedUpAt(LocalDateTime.now());
    assertThat(entitlementService.planOf(MEMBER_ID)).isEqualTo(PlanType.FREE);

    givenEvent(true, "", "", 30);
    assertThat(entitlementService.planOf(MEMBER_ID)).isEqualTo(PlanType.FREE);

    givenEvent(true, "2026-01-01", "2099-01-01", 30);
    when(memberSignupTimeService.findSignupAt(MEMBER_ID)).thenThrow(new RuntimeException("DB 장애"));
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

  @Test
  @DisplayName("하루 한도는 플랜별 하루 설정 키를 읽는다 — 주간 키와 섞이지 않는다 (#368)")
  void dailyLimit_readsDailyKeyOfPlan() {
    when(subscriptionRepository.findByMemberId(MEMBER_ID)).thenReturn(Optional.empty());
    when(systemConfigService.getInt(ConfigKey.FREE_ROUTINE_CREATE_PER_DAY)).thenReturn(5);
    lenient().when(systemConfigService.getInt(ConfigKey.FREE_ROUTINE_CREATE_PER_WEEK)).thenReturn(1);

    assertThat(entitlementService.isWithinLimit(
      MEMBER_ID, Entitlement.ROUTINE_CREATE_PER_DAY, 3)).isTrue();
  }

  @Test
  @DisplayName("Pro 의 하루 한도는 Pro 하루 키를 읽는다")
  void dailyLimit_proReadsProKey() {
    when(systemConfigService.getInt(ConfigKey.PRO_ROUTINE_CREATE_PER_DAY)).thenReturn(2);

    assertThat(entitlementService.isWithinLimit(
      PlanType.PRO, Entitlement.ROUTINE_CREATE_PER_DAY, 2)).isFalse();
  }

  // --- 스냅샷 ---

  @Test
  @DisplayName("스냅샷에 하루 한도가 실린다")
  void snapshot_includesDailyLimit() {
    when(subscriptionRepository.findByMemberId(MEMBER_ID)).thenReturn(Optional.empty());
    lenient().when(systemConfigService.getBoolean(any())).thenReturn(false);
    lenient().when(systemConfigService.getInt(any())).thenReturn(3);
    when(systemConfigService.getInt(ConfigKey.FREE_ROUTINE_CREATE_PER_DAY)).thenReturn(2);

    EntitlementSnapshot snapshot = entitlementService.snapshot(MEMBER_ID);

    assertThat(snapshot.routineCreatePerDay()).isEqualTo(2);
    assertThat(snapshot.routineCreatePerWeek()).isEqualTo(3);
  }

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

  // --- 광고 항상 노출 회원 ---

  private void givenProWithAdsRemoved(String alwaysShownMemberIds) {
    when(subscriptionRepository.findByMemberId(MEMBER_ID))
      .thenReturn(Optional.of(subscription(PlanType.PRO, SubscriptionStatus.ACTIVE, null)));
    lenient().when(systemConfigService.getBoolean(any())).thenReturn(false);
    lenient().when(systemConfigService.getInt(any())).thenReturn(-1);
    lenient().when(systemConfigService.getBoolean(ConfigKey.PRO_ADS_REMOVED)).thenReturn(true);
    lenient().when(systemConfigService.getString(ConfigKey.ADS_ALWAYS_SHOWN_MEMBER_IDS)).thenReturn(alwaysShownMemberIds);
  }

  @Test
  @DisplayName("목록에 있는 회원은 Pro여도 광고가 제거되지 않는다")
  void adsAlwaysShown_listedProMember_adsNotRemoved() {
    givenProWithAdsRemoved("other, m1");

    assertThat(entitlementService.snapshot(MEMBER_ID).adsRemoved()).isFalse();
    assertThat(entitlementService.isAllowed(MEMBER_ID, Entitlement.ADS_REMOVED)).isFalse();
  }

  @Test
  @DisplayName("목록에 없는 Pro 회원은 광고 제거가 유지된다")
  void adsAlwaysShown_unlistedProMember_adsRemoved() {
    givenProWithAdsRemoved("other1,other2");

    assertThat(entitlementService.snapshot(MEMBER_ID).adsRemoved()).isTrue();
    assertThat(entitlementService.isAllowed(MEMBER_ID, Entitlement.ADS_REMOVED)).isTrue();
  }

  @Test
  @DisplayName("공백과 빈 항목이 섞인 목록도 읽는다")
  void adsAlwaysShown_listWithSpacesAndEmptyEntries() {
    givenProWithAdsRemoved(" , other ,  m1  ,, ");

    assertThat(entitlementService.snapshot(MEMBER_ID).adsRemoved()).isFalse();
  }

  @Test
  @DisplayName("목록이 비었거나 공백뿐이면 동작이 바뀌지 않는다")
  void adsAlwaysShown_blankList_unchanged() {
    givenProWithAdsRemoved("  ");

    assertThat(entitlementService.snapshot(MEMBER_ID).adsRemoved()).isTrue();
  }
}
