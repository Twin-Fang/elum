import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/widgets/elum_toast.dart';
import '../../../member/application/plan_access.dart';
import '../../../subscription/application/plan_paywall_entry.dart';
import '../../../subscription/domain/plan_benefit.dart';
import '../../application/routine_notifier.dart';
import 'card_edit_chip.dart';
import 'card_split_sheet.dart';

/// 카드 수정 시트의 `이 카드 더 쉽게` 칩 (서버 카드만)
///
/// Free: PRO 배지, 누르면 Pro 기능 설명 시트 (살 수 없는 동안은 숨김). Pro: 배지 없이 나누기 시트
/// 나눴으면 고치던 카드가 사라졌으니 수정 시트도 닫고 토스트
class CardSplitChip extends ConsumerWidget {
  const CardSplitChip({super.key, required this.routineId, required this.stepId});

  final String routineId;
  final String stepId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(planAccessProvider);
    if (!access.shouldShowEntryFor(PlanBenefit.cardSplit)) return const SizedBox.shrink();
    // 칩 아래 간격은 칩이 보일 때만
    return Center(
      child: Padding(
        padding: EdgeInsets.only(bottom: _bottomGap.h),
        child: CardEditChip(
          asset: AppAssets.iconPlayingCards,
          label: context.l10n.cardSplitChip,
          shouldShowProBadge: access.shouldShowTeaserFor(PlanBenefit.cardSplit),
          onTap: () => _onTapped(context, ref),
        ),
      ),
    );
  }

  /// 칩 ↔ 아래 입력칸 간격
  static const _bottomGap = 12.0;

  Future<void> _onTapped(BuildContext context, WidgetRef ref) async {
    if (!ref.read(planAccessProvider).canSplitCards) {
      await explainProFeature(context, ref, benefit: PlanBenefit.cardSplit);
      return;
    }
    // 시트가 닫힌 뒤에도 토스트를 띄울 수 있게 미리 잡아 둠
    final messenger = ScaffoldMessenger.maybeOf(context);
    final rootContext = Overlay.of(context, rootOverlay: true).context;
    final originalTitle = _findOriginalTitle(ref);
    final addedCount = await CardSplitSheet.show(
      context,
      routineId: routineId,
      stepId: stepId,
      originalTitle: originalTitle,
    );
    if (addedCount == null) return;
    if (context.mounted) Navigator.of(context).pop();
    if (rootContext.mounted) showElumToastOn(messenger, rootContext.l10n.cardSplitDoneToast(addedCount));
  }

  String _findOriginalTitle(WidgetRef ref) {
    for (final step in ref.read(routineFlowProvider).routine?.steps ?? const []) {
      if (step.id == stepId) return step.displayTitle;
    }
    return '';
  }
}
