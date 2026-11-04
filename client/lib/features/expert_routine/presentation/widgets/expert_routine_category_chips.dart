import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/widgets/elum_choice_chip.dart';
import '../../../guardian/domain/routine_template.dart';

/// 분류 칩 줄: 전체 + 분류 6개, 가로 스크롤, 고른 칩은 남색 (이야기 피드 분류 줄과 같은 모양)
class ExpertRoutineCategoryChips extends StatelessWidget {
  const ExpertRoutineCategoryChips({
    super.key,
    required this.selectedCategory,
    required this.onSelected,
  });

  /// null 이면 전체
  final RoutineTemplateCategory? selectedCategory;
  final ValueChanged<RoutineTemplateCategory?> onSelected;

  static const _chipGap = 6.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ElumChoiceChip(
            label: l10n.expertRoutineCategoryAll,
            isSelected: selectedCategory == null,
            onTap: () => onSelected(null),
          ),
          for (final category in RoutineTemplateCategory.values) ...[
            SizedBox(width: _chipGap.w),
            ElumChoiceChip(
              label: category.labelOf(l10n),
              isSelected: category == selectedCategory,
              onTap: () => onSelected(category),
            ),
          ],
        ],
      ),
    );
  }
}
