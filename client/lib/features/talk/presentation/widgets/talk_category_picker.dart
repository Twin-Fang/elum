import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../guardian/domain/routine_template.dart';
import 'talk_choice_row.dart';

/// 분류 고르기: 6개를 세로로, 칸마다 이름 + 한 줄 설명 (올리기·고치기가 함께 쓴다)
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final space = context.space;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final category in RoutineTemplateCategory.values) ...[
          TalkChoiceRow(
            label: category.labelOf(l10n),
            hint: category.hintOf(l10n),
            isSelected: category == selectedCategory,
            onTap: isEnabled ? () => onSelected(category) : null,
          ),
          SizedBox(height: space.xs.h),
        ],
      ],
    );
  }
}
