package com.chuseok22.elumserver.license.application.service;

import com.chuseok22.elumserver.license.core.SubscriptionSource;
import java.time.LocalDateTime;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * 구독 없이 받는 Pro 혜택 판정: 기존 가입자 선물(PRO_GIFT) + 신규가입 체험(PROMO) 중 더 늦게 끝나는 쪽
 * 행 없음·기본 Free 행(isUntouchedSignupFree)인 회원에게만 부르는 쪽이 적용 (구독 행이 우선)
 */
@Component
@RequiredArgsConstructor
public class MemberProPromotion {

  private final ExistingMemberProGift existingMemberProGift;
  private final SignupProEvent signupProEvent;

  /// 혜택 하나: 출처와 Pro 종료 시각
  public record Promotion(SubscriptionSource source, LocalDateTime endsAt) {

  }

  /// 대상이면 종료가 더 늦은 혜택 (같으면 선물), 아니면 빈 값
  public Optional<Promotion> findPromotion(String memberId) {
    Optional<LocalDateTime> giftEndsAt = existingMemberProGift.giftEndsAt(memberId);
    Optional<LocalDateTime> trialEndsAt = signupProEvent.trialEndsAt(memberId);
    if (trialEndsAt.isPresent() && (giftEndsAt.isEmpty() || trialEndsAt.get().isAfter(giftEndsAt.get()))) {
      return Optional.of(new Promotion(SubscriptionSource.PROMO, trialEndsAt.get()));
    }
    return giftEndsAt.map(endsAt -> new Promotion(SubscriptionSource.PRO_GIFT, endsAt));
  }
}
