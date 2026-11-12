import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/server_error_code.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/widgets/pro_upsell_button.dart';
import '../../member/application/member_providers.dart';
import '../../member/application/plan_access.dart';
import '../presentation/plan_actions.dart' as actions;
import '../presentation/plan_paywall_sheet.dart';
import '../domain/plan_benefit.dart';
import 'plan_offer_labels.dart';
import 'plan_store_catalog.dart';
import 'store_purchase_coordinator.dart';

// 혜택 한 줄 문구는 요금제 화면과 한 벌 (다른 기능이 presentation 을 직접 알지 않게)
export '../presentation/plan_benefit_cards.dart' show planBenefitLabel;

/// 다른 기능이 요금제 화면·구매 복원을 여는 입구 (보호자 화면 전용)
///
/// 다른 기능이 subscription 의 presentation 을 직접 알지 않게 하는 자리 (tool/check_layer_imports.dart)
/// 판매 중이 아니면 요금제 화면을 열지 않음 (Pro 안내 팝업만). 이미 Pro 면 구독 관리용으로 엶 — 이룸이 기기는 둘 다 막힘

/// 요금제 화면을 열 수 있는가: 판매 중 · 스토어 연동 + 이미 Pro (판매를 멈춰도 구독 관리·복원 유지, #1132)
final canOpenPlanPaywallProvider = Provider<bool>((ref) {
  if (ref.watch(isPlanStoreEnabledProvider)) return true;
  return ref.watch(isPlanStoreConnectedProvider) &&
      ref.watch(planAccessProvider.select((access) => access.isPro));
});

/// 요금제 화면 열기 (크레딧 부족 팝업 · 설정 줄 · Pro 기능 버튼). [highlight] 는 혜택 맨 위 (연 기능)
Future<void> openPlanPaywall(BuildContext context, WidgetRef ref, {PlanBenefit? highlight}) async {
  if (!ref.read(canOpenPlanPaywallProvider)) return;
  unawaited(ref.read(storePurchaseCoordinatorProvider).start());
  await showPlanPaywall(context, ref, highlight: highlight);
}

/// Pro 미리 보기 판의 버튼 (build 안에서 부름: 상품을 불러오면 `7일 무료로 써 보기` 로 바뀜)
/// 주 버튼은 [highlight] 혜택을 맨 위로 올린 요금제 화면, `Pro 혜택 모두 보기` 는 그냥 요금제 화면
ProUpsellActions watchProUpsellActions(BuildContext context, WidgetRef ref, {PlanBenefit? highlight}) {
  final trial = ref.watch(proUpsellFreeTrialProvider);
  return ProUpsellActions(
    freeTrialLabel: trial == null ? null : planTrialLabel(context.l10n, trial),
    onStart: () => openPlanPaywall(context, ref, highlight: highlight),
    onSeeAllBenefits: () => openPlanPaywall(context, ref),
  );
}

/// 구매 복원 (설정 줄, 판매 스위치와 무관)
Future<void> restorePlanPurchases(BuildContext context, WidgetRef ref) async {
  if (!ref.read(isPlanStoreConnectedProvider)) return;
  await actions.restorePlanPurchases(context, ref);
}

/// 앱 시작 때 구매 소식 듣기 시작 (끝나지 않은 결제를 서버에 다시 확인)
void startStorePurchaseSync(WidgetRef ref) =>
    unawaited(ref.read(storePurchaseCoordinatorProvider).start());

/// 서버가 'Pro 기능'이라 거절한 코드 7개 (앱 판정이 늦었거나 Pro 가 막 끝남). 실패 팝업이 아니라 Pro 안내로 돌림
const _proOnlyRejectionCodes = {
  ServerErrorCode.aiImageNotAllowed,
  ServerErrorCode.imageStyleNotAllowed,
  ServerErrorCode.weeklyReportNotAllowed,
  ServerErrorCode.routineScheduleNotAllowed,
  ServerErrorCode.guardianVoiceNotAllowed,
  ServerErrorCode.routineMemoryProRequired,
  ServerErrorCode.cardSplitProRequired,
};

/// 실패가 'Pro 기능이에요' 거절(403)인가
bool isProOnlyRejection(Object? failure) =>
    failure is AppFailure && _proOnlyRejectionCodes.contains(failure.server?.code);

/// Pro 기능 입구 누름 (Free): 판매 중 > 요금제 화면 · 아니면 안내 팝업 (실패 팝업 아님, [title] 없으면 공통 문구)
Future<void> openProOnlyNotice(BuildContext context, WidgetRef ref, {String? title}) async {
  if (ref.read(planAccessProvider).canPurchasePro) {
    await openPlanPaywall(context, ref);
    return;
  }
  await showElumDialog<void>(
    context: context,
    title: title ?? context.l10n.proOnlyNoticeTitle,
    actions: [ElumDialogAction(label: context.l10n.commonConfirm)],
  );
}

/// Pro 전용 거절 처리: 요금제 판정 새로 받기 > Pro 안내. 처리했으면 true (호출부는 실패 팝업을 띄우지 않음)
Future<bool> handleProOnlyRejection(BuildContext context, WidgetRef ref, Object? failure) async {
  if (!isProOnlyRejection(failure)) return false;
  await showProOnlyNoticeAfterRejection(context, ref);
  return true;
}

/// 서버 Pro 거절을 받은 뒤: 앱이 알던 판정이 틀렸음 (Pro 끝남 등) > 판정 새로 받기 (입구·미리 보기가 바로 맞게) > Pro 안내
Future<void> showProOnlyNoticeAfterRejection(BuildContext context, WidgetRef ref) async {
  ref.invalidate(memberProvider);
  if (!context.mounted) return;
  await openProOnlyNotice(context, ref);
}
