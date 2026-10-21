import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../guardian/domain/routine_template.dart';
import 'talk_choice_row.dart';

/// 분류 고르기: 6개를 3×2 칸으로, 칸마다 이름만 (올리기·고치기가 함께 쓴다)
class TalkCategoryPicker extends StatelessWidget {
  const TalkCategoryPicker({
    super.key,
    required this.selectedCategory,
    required this.onSelected,
    this.isEnabled = true,
  });

  /// null 이면 아직 고르지 않음
  final RoutineTemplateCategory? selectedCategory;
  final ValueChanged<RoutineTemplateCategory> onSelected;

  /// false 면 누를 수 없다 (보내는 중)
  final bool isEnabled;

  // 한 줄에 놓는 칸 수
  static const _columnCount = 3;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    const categories = RoutineTemplateCategory.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var start = 0; start < categories.length; start += _columnCount)
          Padding(
            padding: EdgeInsets.only(
              bottom: start + _columnCount < categories.length
                  ? space.xs.h
                  : 0,
            ),
            // 이름이 두 줄로 넘어가도 같은 줄 칸 높이를 맞춘다
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var column = 0; column < _columnCount; column++) ...[
                    if (column > 0) SizedBox(width: space.xs.w),
                    Expanded(
                      child: start + column < categories.length
                          ? _buildCell(context, categories[start + column])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCell(BuildContext context, RoutineTemplateCategory category) {
    return TalkChoiceRow(
      label: category.labelOf(context.l10n),
      isSelected: category == selectedCategory,
      isLabelCentered: true,
      onTap: isEnabled ? () => onSelected(category) : null,
    );
  }
}
