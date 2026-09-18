package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.core.SubscriptionStatus;
import com.chuseok22.elumserver.license.infrastructure.entity.Subscription;
import java.time.LocalDateTime;

/**
 * 관리자 화면에 보여줄 구독 요약.
 *
 * <p>구독 행이 없는 계정도 <b>Free로 보인다</b>. 화면에서 "구독 없음"과 "Free"를 나누면
 * 보는 사람이 둘의 차이를 따져야 하는데, 실제로는 같은 상태다.
 */
public record AdminSubscriptionSummary(
  PlanType plan,
  SubscriptionStatus status,
  LocalDateTime startedAt,
  LocalDateTime expiresAt,
  SubscriptionSource source,
  String memo,
  /// 만료일이 지나 실제로는 Free로 떨어진 상태인가. 화면에서 따로 표시한다.
  boolean expired
) {

  public static AdminSubscriptionSummary from(Subscription subscription) {
    LocalDateTime now = LocalDateTime.now();
    return new AdminSubscriptionSummary(
      subscription.getPlan(),
      subscription.getStatus(),
      subscription.getStartedAt(),
      subscription.getExpiresAt(),
      subscription.getSource(),
      subscription.getMemo(),
      subscription.effectivePlan(now) != subscription.getPlan()
    );
  }

  /// 구독 행이 없는 계정. 아직 백필되지 않았거나 마이그레이션 이전에 가입한 경우다.
  public static AdminSubscriptionSummary none() {
    return new AdminSubscriptionSummary(
      PlanType.FREE, SubscriptionStatus.ACTIVE, null, null, SubscriptionSource.SIGNUP, null, false
    );
  }
}
