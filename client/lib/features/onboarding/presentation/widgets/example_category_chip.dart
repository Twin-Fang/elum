import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../shared/models/routine_example_category.dart';

/// 예시 분류 선택 항목 (#803): 분류 아이콘 + 분류 이름 + 한 줄 예
///
/// 모양은 옛 목표 칩(Figma `온보딩_목표` 204:1002)을 따른다 — 344 폭 r20, 아이콘 48 (#1285).
/// 선택 로직은 SelectableGroup 이 갖고, 이 위젯은 보이는 모습만 책임진다.
class ExampleCategoryChip extends StatelessWidget {
  const ExampleCategoryChip({
    super.key,
    required this.category,
    required this.isSelected,
  });

  /// 최소 높이 — 두 줄(이름·예)이 들어가고 글꼴을 키우면 늘어난다
  static const minHeight = 76.0;

  static const _horizontalPadding = 14.0;
  static const _verticalPadding = 12.0;
  static const _iconToText = 12.0;
  /// 아이콘 48 (#1285: 3D 그림이라 40 에서는 작아 보임)
  static const _iconSize = 48.0;

  final RoutineExampleCategory category;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      constraints: BoxConstraints(minHeight: minHeight.h),
      padding: EdgeInsets.symmetric(
        horizontal: _horizontalPadding.w,
        vertical: _verticalPadding.h,
      ),
      decoration: BoxDecoration(
        color: isSelected ? colors.goalSelectedFill : colors.surface,
        borderRadius: BorderRadius.circular(context.space.cardRadius.r),
        border: Border.all(
          color: isSelected ? colors.goalSelectedBorder : colors.border,
          width: isSelected
              ? context.space.selectedBorderWidth
              : context.space.borderWidth,
        ),
      ),
      child: Row(
        children: [
          // 장식 그림 (분류 이름이 뜻을 말함)
          Image.asset(
            category.iconAsset,
            width: _iconSize.w,
            height: _iconSize.w,
            excludeFromSemantics: true,
            errorBuilder: (context, error, stack) =>
                SizedBox.square(dimension: _iconSize.w),
          ),
          SizedBox(width: _iconToText.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category.label,
                  style: typo.body.copyWith(color: colors.chipLabel),
                ),
                Text(
                  category.hint,
                  style: typo.caption.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
