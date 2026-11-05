import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/date_labels.dart';
import '../../../l10n/app_localizations.dart';
import '../../member/application/member_providers.dart';
import '../../member/application/plan_access.dart';
import '../../member/domain/member_subscription.dart';
import '../domain/plan_status.dart';
import '../domain/withdraw_store_subscription_notice.dart';

/// 지금 계정의 내 요금제 상태 (Pro 여부는 PlanAccess, 날짜는 회원 정보 `subscription`)
final planStatusProvider = Provider<PlanStatus>((ref) {
  return PlanStatus.from(
    isPro: ref.watch(planAccessProvider).isPro,
    subscription: ref.watch(memberProvider).value?.subscription,
  );
});

/// 지금 구독이 스토어 결제인가 (구독 관리 버튼을 스토어로 보냄)
final memberSubscriptionProvider = Provider<MemberSubscription?>(
  (ref) => ref.watch(memberProvider).value?.subscription,
);

/// 스토어 결제가 갱신 중인가: Pro + 스토어 구독 + 해지 예약 아님 (갱신 여부 모르면 이어진다고 봄)
final hasRenewingStoreSubscriptionProvider = Provider<bool>((ref) {
  final subscription = ref.watch(memberSubscriptionProvider);
  return ref.watch(planAccessProvider).isPro &&
      subscription != null &&
      subscription.isStorePurchase &&
      subscription.willAutoRenew != false;
});

/// 회원탈퇴 경고의 스토어 구독 안내: 갱신 중 아님 > 없음, Google Play > 탈퇴가 해지, App Store > 직접 해지
/// 구분 기준은 기기가 아니라 결제한 스토어 (서버는 Google Play 만 해지 가능)
final withdrawStoreSubscriptionNoticeProvider =
    Provider<WithdrawStoreSubscriptionNotice>((ref) {
  if (!ref.watch(hasRenewingStoreSubscriptionProvider)) {
    return WithdrawStoreSubscriptionNotice.none;
  }
  final source = ref.watch(memberSubscriptionProvider)?.source;
  return source == SubscriptionSource.googleIap
      ? WithdrawStoreSubscriptionNotice.cancelledOnWithdraw
      : WithdrawStoreSubscriptionNotice.cancelInStore;
});

/// 내 요금제 상태 > 한 줄 문구 (설정 줄 · 요금제 화면 `이미 Pro` 가 함께 씀)
String planStatusLabel(AppLocalizations l10n, PlanStatus status) {
  final date = status.date;
  final dateLabel = date == null ? null : l10n.yearMonthDay(date);
  return switch (status.kind) {
    PlanStatusKind.free => l10n.planStatusFree,
    PlanStatusKind.proUnlimited => l10n.planStatusPro,
    PlanStatusKind.proGracePeriod => l10n.planStatusGracePeriod,
    PlanStatusKind.proRenewing =>
      dateLabel == null ? l10n.planStatusPro : l10n.planStatusRenewing(dateLabel),
    PlanStatusKind.proCancelScheduled => dateLabel == null
        ? l10n.planStatusPro
        : l10n.planStatusCancelScheduled(dateLabel),
    PlanStatusKind.proUntil =>
      dateLabel == null ? l10n.planStatusPro : l10n.planStatusUntil(dateLabel),
    PlanStatusKind.proGift =>
      dateLabel == null ? l10n.planStatusGift : l10n.planStatusGiftUntil(dateLabel),
  };
}

/// 설정 줄 값 (짧게): Free · Pro · Pro 선물. 날짜·결제 확인은 묶음 아래 [planStatusFooter] 한 줄로 (줄 값이 두 줄로 꺾이지 않게)
String planStatusShortLabel(AppLocalizations l10n, PlanStatus status) => switch (status.kind) {
  PlanStatusKind.free => l10n.planStatusFree,
  PlanStatusKind.proGift => l10n.planStatusGift,
  _ => l10n.planStatusPro,
};

/// 설정 내 요금제 묶음 아래 한 줄: 갱신일 · 끝나는 날 · 결제 확인. 알릴 것이 없으면(Free · 기간 제한 없음 · 날짜 모름) null
String? planStatusFooter(AppLocalizations l10n, PlanStatus status) {
  final date = status.date;
  final dateLabel = date == null ? null : l10n.yearMonthDay(date);
  return switch (status.kind) {
    PlanStatusKind.free || PlanStatusKind.proUnlimited => null,
    PlanStatusKind.proGracePeriod => l10n.planStatusGracePeriodFooter,
    PlanStatusKind.proRenewing => dateLabel == null ? null : l10n.planStatusRenewingFooter(dateLabel),
    PlanStatusKind.proCancelScheduled => dateLabel == null ? null : l10n.planStatusCancelScheduledFooter(dateLabel),
    PlanStatusKind.proUntil => dateLabel == null ? null : l10n.planStatusUntilFooter(dateLabel),
    PlanStatusKind.proGift => dateLabel == null ? null : l10n.planStatusGiftUntil(dateLabel),
  };
}
