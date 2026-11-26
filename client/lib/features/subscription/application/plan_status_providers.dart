import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/date_labels.dart';
import '../../../core/widgets/pro_badge.dart';
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
/// 지금 가입 체험 중인가 (스토어 구독이 아니라 요금제 화면에서 구독을 시작할 수 있음)
final isProTrialProvider = Provider<bool>((ref) => ref.watch(planStatusProvider).isTrial);

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
  final dateLabel = planStatusDateLabel(l10n, status);
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
    PlanStatusKind.proTrial => _trialLabel(l10n, status),
  };
}

/// `Pro 체험 중, 3일 남았어요` · 마지막 날은 `Pro 체험 중, 오늘까지예요`
String _trialLabel(AppLocalizations l10n, PlanStatus status) {
  final daysLeft = status.trialDaysLeft(DateTime.now());
  return daysLeft == 0 ? l10n.planStatusTrialLastDay : l10n.planStatusTrial(daysLeft);
}

/// 설정 줄 값 (짧게): Free · Pro · Pro 선물. 날짜·결제 확인은 묶음 아래 [planStatusFooter] 한 줄로 (줄 값이 두 줄로 꺾이지 않게)
String planStatusShortLabel(AppLocalizations l10n, PlanStatus status) => switch (status.kind) {
  PlanStatusKind.free => l10n.planStatusFree,
  PlanStatusKind.proGift => l10n.planStatusGift,
  _ => l10n.planStatusPro,
};

/// 설정 줄 칩: Free · Pro · Pro 선물 ([planStatusShortLabel] 과 같은 갈래)
PlanTier planTierOf(PlanStatus status) => switch (status.kind) {
  PlanStatusKind.free => PlanTier.free,
  PlanStatusKind.proGift => PlanTier.proGift,
  _ => PlanTier.pro,
};

/// 설정 내 요금제 묶음 아래 한 줄: 갱신일 · 끝나는 날 · 결제 확인. 알릴 것이 없으면(Free · 기간 제한 없음 · 날짜 모름) null
String? planStatusFooter(AppLocalizations l10n, PlanStatus status) {
  final dateLabel = planStatusDateLabel(l10n, status);
  return switch (status.kind) {
    PlanStatusKind.free || PlanStatusKind.proUnlimited => null,
    PlanStatusKind.proGracePeriod => l10n.planStatusGracePeriodFooter,
    PlanStatusKind.proRenewing => dateLabel == null ? null : l10n.planStatusRenewingFooter(dateLabel),
    PlanStatusKind.proCancelScheduled => dateLabel == null ? null : l10n.planStatusCancelScheduledFooter(dateLabel),
    PlanStatusKind.proUntil => dateLabel == null ? null : l10n.planStatusUntilFooter(dateLabel),
    PlanStatusKind.proGift => dateLabel == null ? null : l10n.planStatusGiftUntil(dateLabel),
    PlanStatusKind.proTrial => _trialLabel(l10n, status),
  };
}

/// 상태 날짜 > 표시 날짜: `…까지` 상태 2개(proUntil · proGift)는 마지막으로 쓸 수 있는 날, 그 외(갱신일 · 끝나는 날)는 그날 그대로
String? planStatusDateLabel(AppLocalizations l10n, PlanStatus status) {
  final date = status.date;
  if (date == null) return null;
  final isUntilLabel = status.kind == PlanStatusKind.proUntil || status.kind == PlanStatusKind.proGift;
  return isUntilLabel ? l10n.yearMonthDayUntil(date) : l10n.yearMonthDay(date.toLocal());
}

/// 끝나는 날이 있는 Pro 4개(선물 · 기간제 · 해지 예약 · 체험)의 남은 날: 화면에 적는 날짜 기준, 그날이 오늘이거나 지났으면 0
/// 그 외 상태 · 날짜 모름은 null (세지 않음)
int? planDaysLeft(PlanStatus status, DateTime now) {
  final date = status.date;
  if (date == null) return null;
  final DateTime lastDay;
  switch (status.kind) {
    case PlanStatusKind.proTrial:
      return status.trialDaysLeft(now);
    case PlanStatusKind.proUntil || PlanStatusKind.proGift:
      lastDay = lastUsableDayOf(date);
    case PlanStatusKind.proCancelScheduled:
      lastDay = date.toLocal();
    case PlanStatusKind.free ||
        PlanStatusKind.proRenewing ||
        PlanStatusKind.proGracePeriod ||
        PlanStatusKind.proUnlimited:
      return null;
  }
  final days = DateTime(lastDay.year, lastDay.month, lastDay.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  return days < 0 ? 0 : days;
}

/// 내 요금제 시트 머리 큰 글 + 그 안에서 크게 세어 보일 숫자 (남은 날이 1 이상일 때만, 아니면 null)
///
/// 체험 > `Pro 체험 중, N일 남았어요` · 끝나는 날 있음 > `N일 남았어요` (마지막 날 `오늘까지 쓸 수 있어요`) · 그 외 > 선물 · Pro 제목
({String text, int? countedDays}) planSheetHeadline(AppLocalizations l10n, PlanStatus status, DateTime now) {
  final daysLeft = planDaysLeft(status, now);
  final countedDays = daysLeft == null || daysLeft == 0 ? null : daysLeft;
  final text = switch (status.kind) {
    PlanStatusKind.proTrial => _trialLabel(l10n, status),
    _ when daysLeft == 0 => l10n.planSheetLastDay,
    _ when daysLeft != null => l10n.planSheetDaysLeft(daysLeft),
    PlanStatusKind.proGift => l10n.myPlanGiftTitle,
    _ => l10n.myPlanProTitle,
  };
  return (text: text, countedDays: countedDays);
}
