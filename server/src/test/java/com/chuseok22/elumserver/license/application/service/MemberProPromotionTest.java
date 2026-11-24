package com.chuseok22.elumserver.license.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.core.SubscriptionStatus;
import com.chuseok22.elumserver.license.infrastructure.entity.Subscription;
import java.time.LocalDateTime;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 선물·체험 겹침과 받는 범위: 깨지면 더 긴 혜택이 짧은 쪽에 덮이거나, 수동 Pro 가 끝난 기존 가입자가 선물 없이 Free 로 떨어진다(#1500)
 */
@ExtendWith(MockitoExtension.class)
class MemberProPromotionTest {

  private static final String MEMBER_ID = "m1";
  private static final LocalDateTime EARLIER = LocalDateTime.of(2099, 1, 1, 0, 0);
  private static final LocalDateTime LATER = LocalDateTime.of(2099, 2, 1, 0, 0);
  private static final LocalDateTime NOW = LocalDateTime.of(2026, 11, 24, 12, 0);

  @Mock
  private ExistingMemberProGift existingMemberProGift;

  @Mock
  private SignupProEvent signupProEvent;

  @InjectMocks
  private MemberProPromotion memberProPromotion;

  private void given(Optional<LocalDateTime> giftEndsAt, Optional<LocalDateTime> trialEndsAt) {
    when(existingMemberProGift.giftEndsAt(MEMBER_ID)).thenReturn(giftEndsAt);
    when(signupProEvent.trialEndsAt(MEMBER_ID)).thenReturn(trialEndsAt);
  }

  @Test
  @DisplayName("체험만 있으면 PROMO 와 체험 종료 시각이다")
  void onlyTrial_isPromo() {
    given(Optional.empty(), Optional.of(LATER));

    assertThat(memberProPromotion.findPromotion(MEMBER_ID, null, NOW))
      .contains(new MemberProPromotion.Promotion(SubscriptionSource.PROMO, LATER));
  }

  @Test
  @DisplayName("선물만 있으면 PRO_GIFT 와 선물 종료 시각이다")
  void onlyGift_isProGift() {
    given(Optional.of(EARLIER), Optional.empty());

    assertThat(memberProPromotion.findPromotion(MEMBER_ID, null, NOW))
      .contains(new MemberProPromotion.Promotion(SubscriptionSource.PRO_GIFT, EARLIER));
  }

  @Test
  @DisplayName("겹치면 더 늦게 끝나는 쪽을 따른다 — 체험이 더 길면 PROMO, 선물이 더 길면 PRO_GIFT")
  void overlap_followsLaterEnd() {
    given(Optional.of(EARLIER), Optional.of(LATER));
    assertThat(memberProPromotion.findPromotion(MEMBER_ID, null, NOW))
      .contains(new MemberProPromotion.Promotion(SubscriptionSource.PROMO, LATER));

    given(Optional.of(LATER), Optional.of(EARLIER));
    assertThat(memberProPromotion.findPromotion(MEMBER_ID, null, NOW))
      .contains(new MemberProPromotion.Promotion(SubscriptionSource.PRO_GIFT, LATER));
  }

  @Test
  @DisplayName("둘 다 없으면(기간이 끝났거나 꺼짐) 혜택이 없다 — Free 로 돌아간다")
  void none_isEmpty() {
    given(Optional.empty(), Optional.empty());

    assertThat(memberProPromotion.findPromotion(MEMBER_ID, null, NOW)).isEmpty();
  }

  // --- 받는 범위: 구독 행 종류별 ---

  private static Subscription row(SubscriptionSource source, PlanType plan, LocalDateTime expiresAt) {
    Subscription subscription = new Subscription();
    subscription.setSource(source);
    subscription.setPlan(plan);
    subscription.setStatus(SubscriptionStatus.ACTIVE);
    subscription.setExpiresAt(expiresAt);
    return subscription;
  }

  @Test
  @DisplayName("관리자 수동 Pro 기간이 끝나면 기존 가입자 선물로 이어진다 — 끝나는 순간 예고 없이 Free 로 떨어지지 않게")
  void endedManualPro_getsGift() {
    when(existingMemberProGift.giftEndsAt(MEMBER_ID)).thenReturn(Optional.of(LATER));

    assertThat(memberProPromotion.findPromotion(MEMBER_ID, row(SubscriptionSource.MANUAL, PlanType.PRO, NOW.minusDays(1)), NOW))
      .contains(new MemberProPromotion.Promotion(SubscriptionSource.PRO_GIFT, LATER));
  }

  @Test
  @DisplayName("관리자가 Free 로 돌린 기존 가입자도 선물은 받지만 가입 체험은 받지 않는다 — 회수가 체험으로 되살아나지 않게")
  void manualFree_getsGiftButNotTrial() {
    when(existingMemberProGift.giftEndsAt(MEMBER_ID)).thenReturn(Optional.of(EARLIER));

    assertThat(memberProPromotion.findPromotion(MEMBER_ID, row(SubscriptionSource.MANUAL, PlanType.FREE, null), NOW))
      .contains(new MemberProPromotion.Promotion(SubscriptionSource.PRO_GIFT, EARLIER));
    verify(signupProEvent, never()).trialEndsAt(any());
  }

  @Test
  @DisplayName("스토어 구독이 끝난 행은 선물도 체험도 받지 않는다 — 환불·해지 뒤 혜택으로 우회하지 않게")
  void endedStoreRow_getsNothing() {
    assertThat(memberProPromotion.findPromotion(MEMBER_ID, row(SubscriptionSource.APPLE_IAP, PlanType.PRO, NOW.minusDays(1)), NOW))
      .isEmpty();
    verify(existingMemberProGift, never()).giftEndsAt(any());
    verify(signupProEvent, never()).trialEndsAt(any());
  }
}
