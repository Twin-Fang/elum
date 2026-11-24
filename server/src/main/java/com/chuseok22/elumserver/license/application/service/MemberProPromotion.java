package com.chuseok22.elumserver.license.application.service;

import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.infrastructure.entity.Subscription;
import java.time.LocalDateTime;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * 구독 없이 받는 Pro 혜택 판정: 기존 가입자 선물(PRO_GIFT) + 신규가입 체험(PROMO) 중 더 늦게 끝나는 쪽
 * 받는 범위 2개: 체험 = 행 없음·가입 기본 Free, 선물 = 체험 범위 + 관리자 수동 행인데 지금 Pro 아님. 스토어 행은 둘 다 아님
 */
@Component
@RequiredArgsConstructor
public class MemberProPromotion {

  private final ExistingMemberProGift existingMemberProGift;
  private final SignupProEvent signupProEvent;

  /// 혜택 하나: 출처와 Pro 종료 시각
  public record Promotion(SubscriptionSource source, LocalDateTime endsAt) {

  }

  /// 대상이면 종료가 더 늦은 혜택 (같으면 선물), 아니면 빈 값. [subscription] 은 구독 행 (없으면 null)
  public Optional<Promotion> findPromotion(String memberId, Subscription subscription, LocalDateTime now) {
    // 체험: 행 없음·가입 기본 Free 만 (관리자 회수가 체험으로 되살아나지 않게)
    boolean canGetTrial = subscription == null || subscription.isUntouchedSignupFree();
    // 선물: 체험 범위 + 수동 Pro 가 끝났거나 Free 로 돌린 기존 가입자 (수동 Pro 종료 뒤 선물로 이어짐)
    boolean canGetGift = canGetTrial || subscription.isManualWithoutProNow(now);
    Optional<LocalDateTime> giftEndsAt = canGetGift ? existingMemberProGift.giftEndsAt(memberId) : Optional.empty();
    Optional<LocalDateTime> trialEndsAt = canGetTrial ? signupProEvent.trialEndsAt(memberId) : Optional.empty();
    if (trialEndsAt.isPresent() && (giftEndsAt.isEmpty() || trialEndsAt.get().isAfter(giftEndsAt.get()))) {
      return Optional.of(new Promotion(SubscriptionSource.PROMO, trialEndsAt.get()));
    }
    return giftEndsAt.map(endsAt -> new Promotion(SubscriptionSource.PRO_GIFT, endsAt));
  }
}
