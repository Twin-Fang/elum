import 'package:flutter/foundation.dart';

import '../../member/domain/member_subscription.dart';

/// 설정 > 내 요금제 줄 상태 7개
enum PlanStatusKind {
  free,

  /// Pro, 다음 결제일에 자동 갱신
  proRenewing,

  /// Pro, 해지 예약 (끝나는 날까지 씀)
  proCancelScheduled,

  /// Pro, 결제 실패 유예 중 (결제 수단 확인 필요)
  proGracePeriod,

  /// Pro, 끝나는 날만 앎 (관리자 발급·프로모션 · 갱신 여부 모름)
  proUntil,

  /// Pro, 기간 제한 없음
  proUnlimited,

  /// Pro 선물 (기존 가입자), 끝나는 날까지
  proGift,

  /// 가입 체험 중 (스토어 구독 아님), 끝나는 날까지
  proTrial,
}

/// 내 요금제 줄에 그릴 것: 상태 + 날짜
@immutable
class PlanStatus {
  const PlanStatus(this.kind, {this.date});

  final PlanStatusKind kind;

  /// 갱신일·끝나는 날 (해당 상태만)
  final DateTime? date;

  bool get isPro => kind != PlanStatusKind.free;

  /// 가입 체험 중인가 (요금제 화면에서 구독을 시작할 수 있음)
  bool get isTrial => kind == PlanStatusKind.proTrial;

  /// 체험이 끝나기까지 남은 날 (끝나는 날이 오늘이면 0, 이미 지났으면 0)
  int trialDaysLeft(DateTime now) {
    final end = date?.toLocal();
    if (end == null) return 0;
    final days = DateTime(end.year, end.month, end.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    return days < 0 ? 0 : days;
  }

  /// Pro 여부(권한 판정 한 곳) + 구독 상태 > 줄 상태
  ///
  /// [isPro] 는 PlanAccess(서버 `entitlements.plan` · 개발자 도구 흉내)를 따른다. [subscription] 은 날짜 표시만
  factory PlanStatus.from({
    required bool isPro,
    MemberSubscription? subscription,
  }) {
    if (!isPro) return const PlanStatus(PlanStatusKind.free);
    final expiresAt = subscription?.expiresAt;
    if (subscription?.isInGracePeriod == true) {
      return PlanStatus(PlanStatusKind.proGracePeriod, date: expiresAt);
    }
    if (subscription == null || expiresAt == null) {
      return const PlanStatus(PlanStatusKind.proUnlimited);
    }
    if (subscription.source == SubscriptionSource.promo) {
      return PlanStatus(PlanStatusKind.proTrial, date: expiresAt);
    }
    if (subscription.source == SubscriptionSource.proGift) {
      return PlanStatus(PlanStatusKind.proGift, date: expiresAt);
    }
    if (!subscription.isStorePurchase) {
      return PlanStatus(PlanStatusKind.proUntil, date: expiresAt);
    }
    return switch (subscription.willAutoRenew) {
      true => PlanStatus(PlanStatusKind.proRenewing, date: expiresAt),
      false => PlanStatus(PlanStatusKind.proCancelScheduled, date: expiresAt),
      null => PlanStatus(PlanStatusKind.proUntil, date: expiresAt),
    };
  }
}
