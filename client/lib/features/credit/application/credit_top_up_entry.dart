import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/analytics/app_analytics.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/server_error_code.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../subscription/application/plan_paywall_entry.dart';
import '../data/credit_repository.dart';
import '../domain/credit_summary.dart';
import '../presentation/ad_reward_watch.dart';
import '../presentation/credit_top_up_sheet.dart';
import 'ad_reward_flow.dart';
import 'credit_costs.dart';
import 'credit_start_gate.dart';

/// 다른 기능이 크레딧 더 받기 시트 · 광고 보상을 여는 입구 (보호자 화면 전용)
///
/// 크레딧 때문에 막히는 곳 3개(홈 일과 만들기 · 일과 만들기 도중 · 그림 다시 그리기)가 모두 같은 시트로 옴.
/// 다른 기능이 credit 의 presentation 을 직접 알지 않게 하는 자리 (tool/check_layer_imports.dart)

/// 광고로 받은 뒤 이어서 할 동작: 받은 순간 팝업 버튼 문구 + 동작 (막힌 일을 다시 시도)
typedef CreditTopUpRetry = ({String label, Future<void> Function() run});

/// 홈 `일과 만들기`가 크레딧 확인에서 막힘: 만드는 중이면 안내 팝업만, 아니면 크레딧 더 받기 시트
///
/// 만드는 중이라 막힌 것은 크레딧을 늘려도 끝나기 전에는 못 만듦 > 광고 · Pro 를 보이지 않음
Future<void> showCreditBlockedNotice(
  BuildContext context,
  WidgetRef ref,
  CreditSummary blocked, {
  CreditTopUpRetry? retry,
}) async {
  // 다 쓴 것이 먼저 — 진행 중인 것이 끝나도 새로 만들 수 없기 때문
  final isGeneratingRoutine = blocked.canStartRoutine && blocked.isGeneratingRoutine;
  AppAnalytics.logCreditBlocked(isGeneratingRoutine: isGeneratingRoutine);
  if (isGeneratingRoutine) {
    await showElumDialog<void>(
      context: context,
      title: context.l10n.creditBlockedBusy,
      keepWordsInTitle: true,
      actions: [ElumDialogAction(label: context.l10n.commonConfirm)],
    );
    return;
  }
  await openCreditTopUp(context, ref, summary: blocked, retry: retry);
}

/// 도중에 서버가 크레딧 부족으로 막음 (일과 만들기 로딩 · 그림 다시 그리기): 잔액을 새로 받아 시트
///
/// 잔액 조회가 실패하면 잔액 없이 연다 (제목은 `크레딧이 조금 모자라요`)
Future<void> openCreditTopUpAfterShortage(
  BuildContext context,
  WidgetRef ref, {
  required CreditTopUpRetry retry,
}) async {
  final summary = await _readSummaryOrNull(ref);
  if (!context.mounted) return;
  await openCreditTopUp(context, ref, summary: summary, retry: retry);
}

/// 크레딧 더 받기 시트 열기 > 고른 길로 이동 (광고 > 받은 순간 팝업 · Pro > 요금제 화면 · 꾸러미 > 내 크레딧)
Future<void> openCreditTopUp(
  BuildContext context,
  WidgetRef ref, {
  CreditSummary? summary,
  CreditTopUpRetry? retry,
}) async {
  final l10n = context.l10n;
  // 오늘 남은 광고 횟수는 열 때마다 새로 받음
  ref.invalidate(adRewardAvailabilityProvider);
  final choice = await showCreditTopUpSheet(
    context,
    title: _sheetTitle(l10n, summary),
    refillLine: l10n.creditTopUpRefillAt(
      summary?.resetLabel ?? ref.read(creditPeriodUnitProvider).resetFallback(l10n),
    ),
  );
  if (!context.mounted) return;
  switch (choice) {
    case CreditTopUpChoice.watchAd:
      await watchAdRewardAndCelebrate(context, ref, retry: retry);
    case CreditTopUpChoice.learnPro:
      await openPlanPaywall(context, ref);
    case CreditTopUpChoice.seePacks:
      await context.push<void>(Routes.guardianMyCredit);
    case null:
      return;
  }
}

/// 광고를 바로 띄움 (홈 크레딧 안내 카드): 받은 순간 팝업 뒤 제자리
Future<void> watchAdForCredits(BuildContext context, WidgetRef ref) =>
    watchAdRewardAndCelebrate(context, ref);

/// 실패가 서버의 크레딧 부족(`AI_CREDIT_INSUFFICIENT`)인가 > 실패 팝업 대신 크레딧 더 받기 시트
bool isCreditInsufficientFailure(Object? failure) =>
    failure is AppFailure && failure.server?.code == ServerErrorCode.aiCreditInsufficient;

/// 시트 제목: 다 씀 > `이번 주(달) 크레딧을 다 썼어요`, 남았지만 모자람 · 잔액 모름 > `크레딧이 조금 모자라요`
String _sheetTitle(AppLocalizations l10n, CreditSummary? summary) {
  if (summary != null && summary.isExhausted) return summary.periodUnit.topUpExhaustedTitle(l10n);
  return l10n.creditTopUpTitleShort;
}

/// 시트 제목용 잔액 (조회 실패 · 크레딧 꺼짐이면 null)
Future<CreditSummary?> _readSummaryOrNull(WidgetRef ref) async {
  try {
    final summary = await ref.read(creditRepositoryProvider).getMine().timeout(creditStartCheckTimeout);
    return summary.enabled ? summary : null;
  } catch (e) {
    AppLogger.error('openCreditTopUpAfterShortage (잔액 조회 실패 — 잔액 없이 연다)', e);
    return null;
  }
}
