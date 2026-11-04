import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
