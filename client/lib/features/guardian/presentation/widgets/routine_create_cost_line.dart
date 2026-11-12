import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/credit_cost_label.dart';
import '../../application/credit_cost_preview.dart';

/// 카드 만들기 버튼 아래 비용 한 줄: `일과 하나에 1개, 그림 한 장에 1개, 지금 12개 있어요`
///
/// 단가 · 잔액은 서버 값. 크레딧이 꺼졌거나 모르면 그리지 않음
class RoutineCreateCostLine extends ConsumerWidget {
  const RoutineCreateCostLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(creditCostPreviewProvider);
    if (preview == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final routineCredits = preview.routineCredits;
    final imageCredits = preview.imageCredits;
    final costs = [
      // 글 무료(Pro 권한)면 단가 0 > `일과 글은 크레딧 없이`
      routineCredits == 0 ? l10n.imageStyleCreditRoutineFree : l10n.imageStyleCreditRoutine(routineCredits),
      if (imageCredits != null) l10n.imageStyleCreditImage(imageCredits),
    ].join(', ');
    return CreditCostLabel(
      text: l10n.questionCreditCostLine(costs, preview.available),
      style: context.typo.creditCaption.copyWith(color: context.colors.textSecondary),
    );
  }
}
