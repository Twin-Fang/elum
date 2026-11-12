import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/widgets/elum_danger_confirm_dialog.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/widgets/elum_type_confirm_dialog.dart';
import '../../credit/application/withdraw_credit_loss.dart';
import '../../subscription/application/plan_paywall_entry.dart';
import '../../subscription/application/plan_status_providers.dart';
import '../../subscription/domain/plan_status.dart';
import '../../subscription/domain/withdraw_store_subscription_notice.dart';

/// App Store 해지 안내 팝업에서 고른 것
enum _AppStoreStepChoice { openStore, proceed }

/// 회원탈퇴 확인 3단계 (#1303): (App Store 갱신 중) 해지 안내 > 경고(잃는 것) > `회원탈퇴` 입력. 모두 통과하면 true
///
/// [creditLookup] 은 화면이 미리 조회해 넘김 (조회 동안 줄에 진행 표시)
Future<bool> confirmWithdraw(
  BuildContext context,
  WidgetRef ref, {
  required WithdrawCreditLossLookup creditLookup,
}) async {
  final storeNotice = ref.read(withdrawStoreSubscriptionNoticeProvider);
  if (storeNotice == WithdrawStoreSubscriptionNotice.cancelInStore) {
    final shouldProceed = await _confirmAppStoreCancelStep(context, ref);
    if (!shouldProceed || !context.mounted) return false;
  }
  final isWarningConfirmed = await _confirmWithdrawWarning(context, ref, storeNotice, creditLookup);
  if (!isWarningConfirmed || !context.mounted) return false;
  return _confirmWithdrawByTyping(context);
}

/// 0단계 (App Store 갱신 중만): 해지 안내 > `구독 관리` 면 스토어를 열고 멈춤, `계속하기` 면 다음 단계
///
/// 서버가 App Store 구독을 해지할 수 없어 탈퇴해도 결제가 이어짐. 건너뛸 수 없게 매번 보임
Future<bool> _confirmAppStoreCancelStep(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final choice = await showElumDialog<_AppStoreStepChoice>(
    context: context,
    title: l10n.guardianSettingsWithdrawAppStoreStepTitle,
    message: l10n.guardianSettingsWithdrawAppStoreStepMessage,
    keepWordsInTitle: true,
    keepWordsInMessage: true,
    actions: [
      ElumDialogAction(
        label: l10n.guardianSettingsWithdrawAppStoreStepContinue,
        value: _AppStoreStepChoice.proceed,
        tone: ElumDialogTone.neutral,
      ),
      ElumDialogAction(label: l10n.planManageSubscription, value: _AppStoreStepChoice.openStore),
    ],
  );
  if (choice == _AppStoreStepChoice.openStore && context.mounted) {
    await openStoreSubscriptionManagement(context, ref);
  }
  return choice == _AppStoreStepChoice.proceed;
}

/// 1단계 경고: 되돌릴 수 없다는 고지 > Pro 가 사라짐 > 크레딧이 사라짐 > 스토어 구독 안내
///
/// 고지 줄은 시안에 없지만 둠 (로그아웃과 달리 되돌릴 수 없음). 고지 문구는 그대로 두고 아래에 줄만 더함
Future<bool> _confirmWithdrawWarning(
  BuildContext context,
  WidgetRef ref,
  WithdrawStoreSubscriptionNotice storeNotice,
  WithdrawCreditLossLookup creditLookup,
) {
  final l10n = context.l10n;
  final storeSubscriptionLine = switch (storeNotice) {
    WithdrawStoreSubscriptionNotice.none => null,
    WithdrawStoreSubscriptionNotice.cancelledOnWithdraw => l10n.guardianSettingsWithdrawGooglePlaySubscriptionNotice,
    WithdrawStoreSubscriptionNotice.cancelInStore => l10n.guardianSettingsWithdrawAppStoreSubscriptionNotice,
  };
  return confirmDangerousAction(
    context,
    icon: ElumDangerIcon.alert,
    title: l10n.guardianSettingsWithdrawConfirmTitle,
    message: [
      l10n.guardianSettingsWithdrawConfirmMessage,
      // 스토어 구독 안내가 붙으면 Pro 줄은 뺌 (`Pro 가 사라져요` 와 `구독은 이어져요` 가 엇갈려 읽힘)
      if (storeSubscriptionLine == null) ?_planLossLine(l10n, ref.read(planStatusProvider)),
      ?_creditLossLine(l10n, creditLookup),
      ?storeSubscriptionLine,
    ].join('\n'),
    actionLabel: l10n.guardianSettingsWithdrawConfirmAction,
    // 날짜·개수가 끼어 길이가 바뀌는 줄이라 어절 단위로 꺾음
    keepWordsInMessage: true,
  );
}

/// 요금제 상태 > 사라지는 Pro 한 줄 (Free 는 null)
String? _planLossLine(AppLocalizations l10n, PlanStatus status) {
  final dateLabel = planStatusDateLabel(l10n, status);
  return switch (status.kind) {
    PlanStatusKind.free => null,
    PlanStatusKind.proGift => dateLabel == null
        ? l10n.guardianSettingsWithdrawProNotice
        : l10n.guardianSettingsWithdrawProGiftNotice(dateLabel),
    PlanStatusKind.proTrial => l10n.guardianSettingsWithdrawProTrialNotice,
    _ => l10n.guardianSettingsWithdrawProNotice,
  };
}

/// 크레딧 조회 결과 > 사라지는 크레딧 한 줄: 모름 > 숫자 없이, 없음(0 · 꺼짐) > null, 산 것 있음 > 함께 표기
String? _creditLossLine(AppLocalizations l10n, WithdrawCreditLossLookup creditLookup) {
  if (!creditLookup.isKnown) return l10n.guardianSettingsWithdrawCreditsUnknownNotice;
  final loss = creditLookup.loss;
  if (loss == null) return null;
  return loss.purchased > 0
      ? l10n.guardianSettingsWithdrawCreditsWithPurchasedNotice(loss.available, loss.purchased)
      : l10n.guardianSettingsWithdrawCreditsNotice(loss.available);
}

/// 2단계: `회원탈퇴` 입력이 맞아야 탈퇴하기가 켜짐
Future<bool> _confirmWithdrawByTyping(BuildContext context) {
  final l10n = context.l10n;
  final requiredPhrase = l10n.guardianSettingsWithdrawTypePhrase;
  return confirmByTyping(
    context,
    requiredPhrase: requiredPhrase,
    title: l10n.guardianSettingsWithdrawTypeTitle,
    message: l10n.guardianSettingsWithdrawTypeMessage(requiredPhrase),
    actionLabel: l10n.guardianSettingsWithdrawTypeAction,
  );
}
