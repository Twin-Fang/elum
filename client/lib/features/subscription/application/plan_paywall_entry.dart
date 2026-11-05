import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/server_error_code.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../member/application/member_providers.dart';
import '../../member/application/plan_access.dart';
import '../presentation/plan_actions.dart' as actions;
import '../presentation/plan_paywall_sheet.dart';
import 'plan_store_catalog.dart';
import 'store_purchase_coordinator.dart';

/// 다른 기능이 요금제 화면·구매 복원을 여는 입구 (보호자 화면 전용)
///
/// 다른 기능이 subscription 의 presentation 을 직접 알지 않게 하는 자리 (tool/check_layer_imports.dart)
/// 판매 스위치가 꺼져 있으면 아무것도 열지 않음 — 이룸이 기기도 여기서 막힘

/// 요금제 화면 열기 (크레딧 부족 팝업 · 설정 줄 · Pro 기능 버튼)
Future<void> openPlanPaywall(BuildContext context, WidgetRef ref) async {
  if (!ref.read(isPlanStoreEnabledProvider)) return;
  unawaited(ref.read(storePurchaseCoordinatorProvider).start());
  await showPlanPaywall(context, ref);
}

/// 구매 복원 (설정 줄)
Future<void> restorePlanPurchases(BuildContext context, WidgetRef ref) async {
  if (!ref.read(isPlanStoreEnabledProvider)) return;
  await actions.restorePlanPurchases(context, ref);
}

/// 앱 시작 때 구매 소식 듣기 시작 (끝나지 않은 결제를 서버에 다시 확인)
void startStorePurchaseSync(WidgetRef ref) =>
    unawaited(ref.read(storePurchaseCoordinatorProvider).start());

/// 서버가 'Pro 기능'이라 거절한 코드 6개 (앱 판정이 늦었거나 Pro 가 막 끝남). 실패 팝업이 아니라 Pro 안내로 돌림
const _proOnlyRejectionCodes = {
  ServerErrorCode.weeklyReportNotAllowed,
  ServerErrorCode.routineTranslateNotAllowed,
  ServerErrorCode.routineScheduleNotAllowed,
  ServerErrorCode.guardianVoiceNotAllowed,
  ServerErrorCode.expertRoutineProOnly,
  ServerErrorCode.routineMemoryProRequired,
};

/// 실패가 'Pro 기능이에요' 거절(403)인가
bool isProOnlyRejection(Object? failure) =>
    failure is AppFailure && _proOnlyRejectionCodes.contains(failure.server?.code);

/// Pro 기능 입구 누름 (Free): 판매 중 > 요금제 화면 · 아니면 안내 팝업 (실패 팝업 아님)
Future<void> openProOnlyNotice(BuildContext context, WidgetRef ref) async {
  if (ref.read(planAccessProvider).canPurchasePro) {
    await openPlanPaywall(context, ref);
    return;
  }
  await showElumDialog<void>(
    context: context,
    title: context.l10n.proOnlyNoticeTitle,
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
