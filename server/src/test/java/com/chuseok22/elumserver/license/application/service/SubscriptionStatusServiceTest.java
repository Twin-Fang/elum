package com.chuseok22.elumserver.license.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.infrastructure.entity.Subscription;
import com.chuseok22.elumserver.license.infrastructure.repository.StorePurchaseRepository;
import com.chuseok22.elumserver.license.infrastructure.repository.SubscriptionRepository;
import java.time.LocalDateTime;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 내 요금제 상태의 선물 표시: 깨지면 앱이 "Pro 선물 · 종료일까지" 대신 기간 없는 Pro 로 보여 언제 끝나는지 모른다
 */
@ExtendWith(MockitoExtension.class)
class SubscriptionStatusServiceTest {

  private static final String MEMBER_ID = "m1";
  private static final LocalDateTime GIFT_ENDS_AT = LocalDateTime.of(2099, 5, 20, 0, 0);

  @Mock
  private EntitlementService entitlementService;

  @Mock
  private SubscriptionRepository subscriptionRepository;

  @Mock
  private StorePurchaseRepository storePurchaseRepository;

  @Mock
  private ExistingMemberProGift existingMemberProGift;

  @InjectMocks
  private SubscriptionStatusService subscriptionStatusService;

  @Test
  @DisplayName("선물로 Pro 인 기본 가입 행 회원은 출처 PRO_GIFT 와 선물 종료 시각을 받는다")
  void status_gift_showsProGiftAndEnd() {
    Subscription signupRow = new Subscription();
    signupRow.setPlan(PlanType.FREE);
    signupRow.setSource(SubscriptionSource.SIGNUP);
    when(entitlementService.planOf(MEMBER_ID)).thenReturn(PlanType.PRO);
    when(subscriptionRepository.findByMemberId(MEMBER_ID)).thenReturn(Optional.of(signupRow));
    when(existingMemberProGift.giftEndsAt(MEMBER_ID)).thenReturn(Optional.of(GIFT_ENDS_AT));

    MemberSubscriptionStatus status = subscriptionStatusService.statusOf(MEMBER_ID);

    assertThat(status.plan()).isEqualTo(PlanType.PRO);
    assertThat(status.source()).isEqualTo(SubscriptionSource.PRO_GIFT);
    assertThat(status.expiresAt()).isEqualTo(GIFT_ENDS_AT);
    assertThat(status.willAutoRenew()).isNull();
  }

  @Test
  @DisplayName("Free 회원은 선물을 묻지 않고 Free 그대로다")
  void status_free_noGiftLookup() {
    when(entitlementService.planOf(MEMBER_ID)).thenReturn(PlanType.FREE);
    when(subscriptionRepository.findByMemberId(MEMBER_ID)).thenReturn(Optional.empty());

    MemberSubscriptionStatus status = subscriptionStatusService.statusOf(MEMBER_ID);

    assertThat(status.plan()).isEqualTo(PlanType.FREE);
    assertThat(status.source()).isEqualTo(SubscriptionSource.SIGNUP);
  }
}
