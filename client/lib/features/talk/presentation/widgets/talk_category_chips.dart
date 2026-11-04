import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_choice_chip.dart';
import '../../../guardian/domain/routine_template.dart';

/// 분류 칩 줄: 전체 + 분류 6개, 가로 스크롤, 고른 칩은 진한 바탕 (시안 1783:6645)
class TalkCategoryChips extends StatelessWidget {
  const TalkCategoryChips({
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
    final space = context.space;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: space.screenH.w),
      child: Row(
        children: [
          ElumChoiceChip(
            label: l10n.talkCategoryAll,
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
