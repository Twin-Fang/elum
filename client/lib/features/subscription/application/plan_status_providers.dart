import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/date_labels.dart';
import '../../../l10n/app_localizations.dart';
import '../../member/application/member_providers.dart';
import '../../member/application/plan_access.dart';
import '../../member/domain/member_subscription.dart';
import '../domain/plan_status.dart';

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
  };
}
