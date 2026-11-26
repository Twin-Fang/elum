import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/layout/app_text_scale.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_guide_panel.dart';
import '../../../core/widgets/elum_secondary_button.dart';
import '../../member/domain/member_subscription.dart';
import '../application/plan_status_providers.dart';
import '../domain/plan_status.dart';
import 'my_plan_sheet_hero.dart';

/// 내 요금제 시트에서 고른 것 (닫기 · 바깥 누름은 null)
enum MyPlanSheetChoice { manageSubscription, startSubscription, restorePurchases }

/// 내 요금제 시트 띄우기 > 고른 것 (동작은 여는 쪽이 원래 화면 context 로 함)
Future<MyPlanSheetChoice?> showMyPlanSheet(
  BuildContext context, {
  required bool canStartSubscription,
  required bool canRestorePurchases,
}) => showElumGuideSheet<MyPlanSheetChoice>(
  context: context,
  builder: (_) => MyPlanSheet(
    canStartSubscription: canStartSubscription,
    canRestorePurchases: canRestorePurchases,
  ),
);

/// 내 요금제 시트 (안내 뼈대, #1303 · #1516): 제목 > 금빛 회원 카드 > 날짜 줄 > 결제한 곳 줄 > 끝난 뒤 설명 > 주 버튼 > 구매 복원 | 닫기
///
/// 주 버튼 3갈래: 스토어 구독 > 구독 관리 · 체험 중 + 판매 중 > 구독 시작하기 · 그 외 > 없음 (닫기만)
class MyPlanSheet extends ConsumerWidget {
  const MyPlanSheet({super.key, required this.canStartSubscription, required this.canRestorePurchases});

  /// 요금제 화면에서 구독을 시작할 수 있는가 (체험 중 + 판매 중)
  final bool canStartSubscription;

  /// 스토어 연동이라 구매 복원을 할 수 있는가
  final bool canRestorePurchases;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(planStatusProvider);
    final subscription = ref.watch(memberSubscriptionProvider);
    final isStorePurchase = subscription?.isStorePurchase ?? false;
    final dateLabel = planStatusDateLabel(l10n, status);
    final storeName = _storeNameOf(l10n, subscription?.source);
    final note = _afterNoteOf(l10n, status, dateLabel: dateLabel, isStorePurchase: isStorePurchase);
    void choose(MyPlanSheetChoice choice) => Navigator.of(context).pop(choice);

    final hasPrimaryAction = isStorePurchase || canStartSubscription;
    final space = context.space;

    return ElumGuidePanel(
      placement: ElumGuidePlacement.sheet,
      title: l10n.planSettingsLabel,
      // 내용: 회원 카드(요금제 · 남은 날 · 혜택) > 날짜 > 결제한 곳 > 끝난 뒤 어떻게 되는지
      content: [
        MyPlanSheetHero(status: status),
        SizedBox(height: space.md.h),
        if (dateLabel != null && status.kind != PlanStatusKind.proGracePeriod)
          ElumGuideRow(
            iconAsset: AppAssets.iconCalendar,
            label: status.kind == PlanStatusKind.proRenewing ? l10n.planSheetNextPaymentLabel : l10n.planSheetEndDateLabel,
            value: dateLabel,
          ),
        if (storeName != null)
          ElumGuideRow(iconAsset: AppAssets.iconCoins, label: l10n.planSheetStoreLabel, value: storeName),
        if (note != null) ...[const ElumGuideDivider(), ElumGuideNote(text: note)],
        // 주 버튼이 없으면 뼈대가 버튼 앞 간격을 두지 않아 여기서 띄움
        if (!hasPrimaryAction) SizedBox(height: space.xs.h),
      ],
      primaryAction: switch ((isStorePurchase, canStartSubscription)) {
        (true, _) => ElumGuideAction(
          label: l10n.planManageSubscription,
          onTap: () => choose(MyPlanSheetChoice.manageSubscription),
        ),
        (false, true) => ElumGuideAction(
          label: l10n.planSubscribe,
          onTap: () => choose(MyPlanSheetChoice.startSubscription),
        ),
        _ => null,
      },
      secondaryActions: [
        _RestoreAndCloseActions(
          onRestore: canRestorePurchases ? () => choose(MyPlanSheetChoice.restorePurchases) : null,
          onClose: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  /// 결제한 스토어 > 이름 (스토어 결제가 아니면 null > 줄 숨김)
  static String? _storeNameOf(AppLocalizations l10n, SubscriptionSource? source) => switch (source) {
    SubscriptionSource.appleIap => l10n.planSheetStoreAppStore,
    SubscriptionSource.googleIap => l10n.planSheetStoreGooglePlay,
    _ => null,
  };

  /// 상태 > 끝난 뒤 설명 한 줄. 갱신 여부를 모르는 스토어 구독(proUntil)은 단정하지 않아 null
  static String? _afterNoteOf(
    AppLocalizations l10n,
    PlanStatus status, {
    required String? dateLabel,
    required bool isStorePurchase,
  }) => switch (status.kind) {
    PlanStatusKind.free => null,
    PlanStatusKind.proRenewing => dateLabel == null ? null : l10n.planSheetRenewingNote(dateLabel),
    PlanStatusKind.proGracePeriod => l10n.planStatusGracePeriodFooter,
    PlanStatusKind.proUnlimited => l10n.planSheetUnlimitedNote,
    PlanStatusKind.proUntil => isStorePurchase ? null : l10n.planSheetEndsToFreeNote,
    PlanStatusKind.proCancelScheduled ||
    PlanStatusKind.proGift ||
    PlanStatusKind.proTrial => l10n.planSheetEndsToFreeNote,
  };
}

/// 보조 버튼 묶음: `구매 복원` | `닫기` 한 줄 (큰 글자면 세로로), 복원할 수 없으면 `닫기` 하나
class _RestoreAndCloseActions extends StatelessWidget {
  const _RestoreAndCloseActions({required this.onRestore, required this.onClose});

  /// null 이면 구매 복원 버튼 없음 (스토어 연동 아님)
  final VoidCallback? onRestore;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final space = context.space;
    final onRestore = this.onRestore;
    final close = ElumSecondaryButton(label: l10n.commonClose, onTap: onClose);
    if (onRestore == null) return close;
    final restore = ElumSecondaryButton(label: l10n.planRestore, onTap: onRestore);
    if (AppTextScale.isLargeTextOf(context)) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [restore, SizedBox(height: space.xs.h), close],
      );
    }
    return Row(
      children: [
        Expanded(child: restore),
        SizedBox(width: space.xs.w),
        Expanded(child: close),
      ],
    );
  }
}
