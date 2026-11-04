import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_sheet_action_row.dart';
import '../../../../core/widgets/elum_sheet_frame.dart';
import '../../../credit/application/image_regenerate_cost.dart';
import '../../../member/application/plan_access.dart';

/// 카드 그림 다시 그리기 확인 시트: 제목 > 설명 > 비용 한 줄 (> Free · 판매 중이면 Pro 혜택 한 줄) > 취소 · 다시 그리기
///
/// 비용 3가지: `Pro 무료 (오늘 N회 남음)` · `크레딧을 쓰지 않아요`(크레딧 꺼짐·단가 0) · `크레딧 N개`.
/// 비용을 못 받으면 `크레딧을 써요` 로 두고 진행은 막지 않음 (서버가 예약 때 다시 판정)
class CardRegenerateSheet extends ConsumerWidget {
  const CardRegenerateSheet({super.key});

  /// 확인하면 true, 취소·내려 닫음이면 false
  static Future<bool> show(BuildContext context) async {
    final isConfirmed = await showElumSheet<bool>(
      context: context,
      builder: (_) => const CardRegenerateSheet(),
    );
    return isConfirmed ?? false;
  }

  /// 비용 > Pro 혜택 줄 · 혜택 줄 > 버튼
  static const _costToHint = 8.0;
  static const _bodyToButtons = 24.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final costAsync = ref.watch(imageRegenerateCostProvider);
    final cost = costAsync.value;
    final isFree = cost != null && (cost.freeLeftToday > 0 || !cost.isCreditEnabled || cost.credits <= 0);
    final shouldShowProHint = !isFree && ref.watch(planAccessProvider).shouldShowProTeaser;

    return ElumSheetFrame(
      title: l10n.cardRegenerateSheetTitle,
      description: l10n.cardRegenerateSheetBody,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _costLabel(context, cost),
            textAlign: TextAlign.center,
            style: context.typo.settingsTileLabel.copyWith(color: colors.textPrimary),
          ),
          if (shouldShowProHint) ...[
            SizedBox(height: _costToHint.h),
            Text(
              l10n.cardRegenerateProHint,
              textAlign: TextAlign.center,
              style: context.typo.caption.copyWith(color: colors.textSecondary),
            ),
          ],
          SizedBox(height: _bodyToButtons.h),
          ElumSheetActionRow(
            cancelLabel: l10n.commonCancel,
            onCancel: () => Navigator.of(context).pop(false),
            confirmLabel: l10n.cardRegenerateConfirm,
            // 비용을 받는 동안만 잠깐 막음 (실패면 진행 가능)
            onConfirm: costAsync.isLoading ? null : () => Navigator.of(context).pop(true),
            isLoading: costAsync.isLoading,
          ),
        ],
      ),
    );
  }

  /// 비용 > 한 줄: 무료 횟수 남음 > 크레딧 안 씀 > 크레딧 N개 (모르면 크레딧을 써요)
  static String _costLabel(BuildContext context, ImageRegenerateCost? cost) {
    final l10n = context.l10n;
    if (cost == null) return l10n.cardRegenerateCostUnknown;
    if (cost.freeLeftToday > 0) return l10n.cardRegenerateCostProFree(cost.freeLeftToday);
    if (!cost.isCreditEnabled || cost.credits <= 0) return l10n.cardRegenerateCostFree;
    return l10n.cardRegenerateCostCredits(cost.credits);
  }
}
