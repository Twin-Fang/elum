import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/elum_toast.dart';
import '../../../core/widgets/show_failure.dart';
import '../../subscription/application/credit_purchase_coordinator.dart';
import '../../subscription/application/credit_purchase_notifier.dart';
import '../domain/credit_pack.dart';
import '../domain/credit_purchase.dart';

/// 결제: 보호자 암호 확인 > 결제창 (결과는 구매 단계로 화면에 옴). 암호를 안 넣고 돌아오면 아무것도 안 함
Future<void> confirmGuardianAndBuyCredits(BuildContext context, WidgetRef ref, CreditPack pack) async {
  final isConfirmed = await context.push<bool>(Routes.guardianPlanPin);
  if (isConfirmed != true || !context.mounted) return;
  await ref.read(creditPurchaseCoordinatorProvider).buy(pack);
}

/// 구매 단계 > 안내 한 번: 받음 = 알림 띠, 실패 = 실패 팝업 (닫으면 고르는 상태로)
Future<void> showCreditPurchaseOutcome(BuildContext context, WidgetRef ref, CreditPurchaseState state) async {
  final l10n = context.l10n; // await 뒤에서 context 를 읽지 않으려고 미리 잡는다
  switch (state.phase) {
    case CreditPurchasePhase.granted:
      showElumToast(context, l10n.creditReceivedTitle(state.grantedCredits));
    case CreditPurchasePhase.failed:
      await showFailure(
        context,
        state.failure,
        title: switch (state.failureCode) {
          CreditPurchaseErrorCode.account => l10n.planAccountFailedTitle,
          CreditPurchaseErrorCode.verify => l10n.planVerifyFailedTitle,
          _ => l10n.planPurchaseFailedTitle,
        },
        fallback: l10n.planFailedFallback,
        fallbackCode: state.failureCode ?? CreditPurchaseErrorCode.store,
      );
    case CreditPurchasePhase.idle || CreditPurchasePhase.busy || CreditPurchasePhase.needsRecheck:
      return;
  }
  ref.read(creditPurchaseStateProvider.notifier).acknowledged();
}
