import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../domain/plan_purchase_state.dart';

/// 요금제 화면 결제 단계. 전이 규칙은 [reducePlanPurchase] 한 곳
class PlanPurchaseNotifier extends Notifier<PlanPurchaseState> {
  @override
  PlanPurchaseState build() => PlanPurchaseState.idle;

  /// 사건 반영. 바뀌었으면 true (결제 시작 요청이 받아들여졌는지 확인용)
  bool apply(PlanPurchaseEvent event) {
    final before = state;
    final after = reducePlanPurchase(before, event);
    if (after == before) return false;
    AppLogger.info('[plan purchase] ${before.phase.name} -> ${after.phase.name}');
    state = after;
    return true;
  }
}

final planPurchaseStateProvider =
    NotifierProvider<PlanPurchaseNotifier, PlanPurchaseState>(
      PlanPurchaseNotifier.new,
    );
