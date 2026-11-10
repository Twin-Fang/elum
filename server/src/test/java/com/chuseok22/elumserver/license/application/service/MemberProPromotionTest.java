package com.chuseok22.elumserver.license.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.license.core.SubscriptionSource;
import java.time.LocalDateTime;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 선물·체험 겹침: 깨지면 더 긴 혜택이 짧은 쪽에 덮여 Pro 가 일찍 끝나거나 종료일 표시가 틀린다
 */
@ExtendWith(MockitoExtension.class)
class MemberProPromotionTest {

  private static final String MEMBER_ID = "m1";
  private static final LocalDateTime EARLIER = LocalDateTime.of(2099, 1, 1, 0, 0);
  private static final LocalDateTime LATER = LocalDateTime.of(2099, 2, 1, 0, 0);

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

    assertThat(memberProPromotion.findPromotion(MEMBER_ID))
      .contains(new MemberProPromotion.Promotion(SubscriptionSource.PROMO, LATER));
  }

  @Test
  @DisplayName("선물만 있으면 PRO_GIFT 와 선물 종료 시각이다")
  void onlyGift_isProGift() {
    given(Optional.of(EARLIER), Optional.empty());

    assertThat(memberProPromotion.findPromotion(MEMBER_ID))
      .contains(new MemberProPromotion.Promotion(SubscriptionSource.PRO_GIFT, EARLIER));
  }

  @Test
  @DisplayName("겹치면 더 늦게 끝나는 쪽을 따른다 — 체험이 더 길면 PROMO, 선물이 더 길면 PRO_GIFT")
  void overlap_followsLaterEnd() {
    given(Optional.of(EARLIER), Optional.of(LATER));
    assertThat(memberProPromotion.findPromotion(MEMBER_ID))
      .contains(new MemberProPromotion.Promotion(SubscriptionSource.PROMO, LATER));

    given(Optional.of(LATER), Optional.of(EARLIER));
    assertThat(memberProPromotion.findPromotion(MEMBER_ID))
      .contains(new MemberProPromotion.Promotion(SubscriptionSource.PRO_GIFT, LATER));
  }

  @Test
  @DisplayName("둘 다 없으면(기간이 끝났거나 꺼짐) 혜택이 없다 — Free 로 돌아간다")
  void none_isEmpty() {
    given(Optional.empty(), Optional.empty());

    assertThat(memberProPromotion.findPromotion(MEMBER_ID)).isEmpty();
  }
}
