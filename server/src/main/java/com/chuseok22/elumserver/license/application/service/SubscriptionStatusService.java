package com.chuseok22.elumserver.license.application.service;

import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.core.StorePurchaseState;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.infrastructure.entity.StorePurchase;
import com.chuseok22.elumserver.license.infrastructure.entity.Subscription;
import com.chuseok22.elumserver.license.infrastructure.repository.StorePurchaseRepository;
import com.chuseok22.elumserver.license.infrastructure.repository.SubscriptionRepository;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 회원 구독 상태 조회: 적용 요금제(EntitlementService) + 구독 행 + 연결된 스토어 구매(자동 갱신·유예) + 선물·체험 종료일
 * 조회가 실패해도 내 정보 응답을 막지 않음 > Free 로 보고 로그 (SystemConfigEntitlementService 와 같은 기준)
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class SubscriptionStatusService {

  private static final Set<SubscriptionSource> STORE_SOURCES = Set.of(SubscriptionSource.APPLE_IAP, SubscriptionSource.GOOGLE_IAP);

  private final EntitlementService entitlementService;
  private final SubscriptionRepository subscriptionRepository;
  private final StorePurchaseRepository storePurchaseRepository;
  private final MemberProPromotion memberProPromotion;

  @Transactional(readOnly = true)
  public MemberSubscriptionStatus statusOf(String memberId) {
    try {
      PlanType plan = entitlementService.planOf(memberId);
      Optional<Subscription> subscription = subscriptionRepository.findByMemberId(memberId);
      // 행 없음·가입 기본 Free 행인데 Pro = 기존 가입자 선물(PRO_GIFT) 또는 신규가입 체험(PROMO), 종료일 표시
      boolean isPromotionCandidate = plan == PlanType.PRO && subscription.map(Subscription::isUntouchedSignupFree).orElse(true);
      Optional<MemberProPromotion.Promotion> promotion = isPromotionCandidate
        ? memberProPromotion.findPromotion(memberId)
        : Optional.empty();
      if (promotion.isPresent()) {
        return new MemberSubscriptionStatus(PlanType.PRO, promotion.get().source(), null, promotion.get().endsAt(), null, false);
      }
      if (subscription.isEmpty()) {
        return MemberSubscriptionStatus.free();
      }
      return statusFrom(plan, subscription.get());
    } catch (RuntimeException e) {
      log.warn("[subscription status] read failed, treating as FREE : memberId={}", memberId, e);
      return MemberSubscriptionStatus.free();
    }
  }

  private MemberSubscriptionStatus statusFrom(PlanType plan, Subscription subscription) {
    boolean isPro = plan == PlanType.PRO;
    StorePurchase purchase = STORE_SOURCES.contains(subscription.getSource()) && subscription.getExternalRef() != null
      ? storePurchaseRepository.findById(subscription.getExternalRef()).orElse(null)
      : null;
    boolean isStorePro = isPro && purchase != null;
    return new MemberSubscriptionStatus(
      plan,
      subscription.getSource(),
      isStorePro ? purchase.getProductId() : null,
      isPro ? subscription.getExpiresAt() : null,
      isStorePro ? purchase.getWillAutoRenew() : null,
      isStorePro && purchase.getState() == StorePurchaseState.IN_GRACE_PERIOD
    );
  }
}
