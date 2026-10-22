import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../guardian/domain/routine_template.dart';
import 'talk_category_chips.dart';

/// 분류 고르기: 6개를 3×2 알약 칩으로 (피드 분류 칩과 같은 모양, 올리기 · 고치기가 함께 쓴다)
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

  /// 한 줄 칸 수 · 칸 사이 (가로 · 세로 같은 12, 시안 1870:9475)
  static const _columnCount = 3;
  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    const categories = RoutineTemplateCategory.values;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var start = 0; start < categories.length; start += _columnCount)
          Padding(
            padding: EdgeInsets.only(
              bottom: start + _columnCount < categories.length ? _gap.h : 0,
            ),
            // 이름이 두 줄로 넘어가도 같은 줄 칸 높이를 맞춘다
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var column = 0; column < _columnCount; column++) ...[
                    if (column > 0) SizedBox(width: _gap.w),
                    Expanded(
                      child: start + column < categories.length
                          ? TalkCategoryChip(
                              label: categories[start + column].labelOf(l10n),
                              isSelected:
                                  categories[start + column] ==
                                  selectedCategory,
                              isExpanded: true,
                              onTap: isEnabled
                                  ? () => onSelected(categories[start + column])
                                  : null,
                            )
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
}
