import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/server_error_code.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/widgets/pro_upsell_button.dart';
import '../../credit/application/credit_costs.dart';
import '../../member/application/member_providers.dart';
import '../../member/application/plan_access.dart';
import '../presentation/my_plan_sheet.dart';
import '../presentation/plan_actions.dart' as actions;
import '../presentation/plan_benefit_cards.dart' show planBenefitLabel;
import '../presentation/plan_paywall_sheet.dart';
import '../presentation/pro_feature_explain_sheet.dart';
import '../domain/plan_benefit.dart';
import 'plan_offer_labels.dart';
import 'plan_status_providers.dart';
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

/// 설정 `내 요금제` 줄 누름 (#1303): Pro > 내 요금제 시트 > 고른 동작 · Free > 요금제 화면 (열 수 있을 때만)
Future<void> openMyPlan(BuildContext context, WidgetRef ref) async {
  if (!ref.read(planAccessProvider).isPro) {
    await openPlanPaywall(context, ref);
    return;
  }
  final choice = await showMyPlanSheet(
    context,
    canStartSubscription: ref.read(isProTrialProvider) && ref.read(canOpenPlanPaywallProvider),
    canRestorePurchases: ref.read(isPlanStoreConnectedProvider),
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case MyPlanSheetChoice.manageSubscription:
      await actions.openSubscriptionManagement(context, ref);
    case MyPlanSheetChoice.startSubscription:
      await openPlanPaywall(context, ref);
    case MyPlanSheetChoice.restorePurchases:
      await restorePlanPurchases(context, ref);
  }
}

/// 결제한 스토어의 구독 관리 화면 열기 (회원탈퇴 전 해지 안내)
Future<void> openStoreSubscriptionManagement(BuildContext context, WidgetRef ref) =>
    actions.openSubscriptionManagement(context, ref);

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

/// Pro 기능 입구 누름 (Free): 판매 중 > 요금제 화면 ([benefit] 을 맨 위로) · 아니면 안내 팝업 (실패 팝업 아님, [title] 없으면 공통 문구)
///
/// 안내 팝업 본문: [benefit] 혜택 한 줄 > 지금 할 수 있는 길 한 줄 (막다른 확인 버튼만 남기지 않음)
Future<void> openProOnlyNotice(BuildContext context, WidgetRef ref, {String? title, PlanBenefit? benefit}) async {
  if (ref.read(planAccessProvider).canPurchasePro) {
    await openPlanPaywall(context, ref, highlight: benefit);
    return;
  }
  final l10n = context.l10n;
  final benefitLine = benefit == null
      ? null
      : planBenefitLabel(
          l10n,
          benefit,
          ref.read(creditPeriodUnitProvider),
          freeRegenerateDailyCap: ref.read(freeImageRegenerateDailyCapProvider),
        );
  await showElumDialog<void>(
    context: context,
    title: title ?? l10n.proOnlyNoticeTitle,
    message: [?benefitLine, _proOnlyFreeAlternative(l10n, benefit)].join('\n'),
    actions: [ElumDialogAction(label: l10n.commonConfirm)],
  );
}

/// 흐름 안 Pro 입구 누름 (카드 검토 · 그림 방식, Free): 설명 시트 먼저 > `Pro 알아보기` 를 골랐을 때만 요금제 화면 ([benefit] 맨 위)
///
/// 요금제 화면으로 바로 넘기지 않음 (하던 일을 가로채지 않게). 살 수 없는 동안은 버튼 없이 지금 할 수 있는 길 한 줄
Future<void> explainProFeature(BuildContext context, WidgetRef ref, {required PlanBenefit benefit}) async {
  final l10n = context.l10n;
  final canLearnPro = ref.read(planAccessProvider).canPurchasePro;
  final isLearnProChosen = await showProFeatureExplainSheet(
    context,
    illustrationAsset: _explainIllustrationOf(benefit),
    title: planBenefitLabel(
      l10n,
      benefit,
      ref.read(creditPeriodUnitProvider),
      freeRegenerateDailyCap: ref.read(freeImageRegenerateDailyCapProvider),
    ),
    description: _explainReasonOf(l10n, benefit),
    freeAlternativeLine: canLearnPro ? null : _proOnlyFreeAlternative(l10n, benefit),
    canLearnPro: canLearnPro,
  );
  if (!isLearnProChosen || !context.mounted) return;
  await openPlanPaywall(context, ref, highlight: benefit);
}

/// 설명 시트 그림: 카드 나누기 > 책, 그 외 (그림 · 다시 그리기) > 별
String _explainIllustrationOf(PlanBenefit benefit) => switch (benefit) {
  PlanBenefit.cardSplit => AppAssets.featureIconGuide,
  _ => AppAssets.featureIconStar,
};

/// 설명 시트 왜 좋은지 한 줄 (흐름 안 입구 3개만, 그 외 null)
String? _explainReasonOf(AppLocalizations l10n, PlanBenefit benefit) => switch (benefit) {
  PlanBenefit.aiImageStyles => l10n.proExplainAiImageStylesReason,
  PlanBenefit.cardSplit => l10n.proExplainCardSplitReason,
  PlanBenefit.freeImageRegenerate => l10n.proExplainFreeImageRegenerateReason,
  _ => null,
};

/// Pro 없이 지금 할 수 있는 길 (기능별, 없으면 공통 문구)
String _proOnlyFreeAlternative(AppLocalizations l10n, PlanBenefit? benefit) => switch (benefit) {
  PlanBenefit.aiImageStyles => l10n.proOnlyFreeAlternativeAiImage,
  PlanBenefit.routineSchedule => l10n.proOnlyFreeAlternativeSchedule,
  PlanBenefit.guardianVoice => l10n.proOnlyFreeAlternativeVoice,
  PlanBenefit.cardSplit => l10n.proOnlyFreeAlternativeCardSplit,
  PlanBenefit.cardExportAllThemes || PlanBenefit.cardExportAllLayouts => l10n.proOnlyFreeAlternativeCardExport,
  _ => l10n.proOnlyFreeAlternative,
};

/// 서버 Pro 거절 코드 > 그 기능의 혜택 (안내 팝업 · 요금제 화면 맨 위)
PlanBenefit? _benefitOfRejection(Object? failure) {
  if (failure is! AppFailure) return null;
  return switch (failure.server?.code) {
    ServerErrorCode.aiImageNotAllowed || ServerErrorCode.imageStyleNotAllowed => PlanBenefit.aiImageStyles,
    ServerErrorCode.weeklyReportNotAllowed => PlanBenefit.weeklyReport,
    ServerErrorCode.routineScheduleNotAllowed => PlanBenefit.routineSchedule,
    ServerErrorCode.guardianVoiceNotAllowed => PlanBenefit.guardianVoice,
    ServerErrorCode.routineMemoryProRequired => PlanBenefit.routineMemory,
    ServerErrorCode.cardSplitProRequired => PlanBenefit.cardSplit,
    _ => null,
  };
}

/// Pro 전용 거절 처리: 요금제 판정 새로 받기 > Pro 안내. 처리했으면 true (호출부는 실패 팝업을 띄우지 않음)
Future<bool> handleProOnlyRejection(BuildContext context, WidgetRef ref, Object? failure) async {
  if (!isProOnlyRejection(failure)) return false;
  await showProOnlyNoticeAfterRejection(context, ref, benefit: _benefitOfRejection(failure));
  return true;
}

/// 서버 Pro 거절을 받은 뒤: 앱이 알던 판정이 틀렸음 (Pro 끝남 등) > 판정 새로 받기 (입구·미리 보기가 바로 맞게) > Pro 안내
Future<void> showProOnlyNoticeAfterRejection(BuildContext context, WidgetRef ref, {PlanBenefit? benefit}) async {
  ref.invalidate(memberProvider);
  if (!context.mounted) return;
  await openProOnlyNotice(context, ref, benefit: benefit);
}
