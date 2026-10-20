import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 하나만 고르는 줄: 이름 + (있으면) 한 줄 설명, 고른 줄은 테두리와 바탕이 바뀐다
/// 신고 사유·분류 고르기가 함께 쓴다
class TalkChoiceRow extends StatelessWidget {
  const TalkChoiceRow({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.hint,
  });

  final String label;
  final String? hint;
  final bool isSelected;

  /// null 이면 잠긴다 (보내는 중)
  final VoidCallback? onTap;

  static const _rowMinHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final hint = this.hint;
    final borderWidth = isSelected
        ? space.selectedBorderWidth
        : space.borderWidth;

    return Semantics(
      selected: isSelected,
      button: true,
      child: AppPressable(
        onTap: onTap,
        scaleDown: AppPressable.scaleCard,
        child: Container(
          constraints: BoxConstraints(minHeight: _rowMinHeight.h),
          padding: EdgeInsets.symmetric(
            horizontal: space.sm.w,
            vertical: space.xs.h,
          ),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: isSelected ? colors.goalSelectedFill : colors.surface,
            borderRadius: BorderRadius.circular(space.fieldRadius.r),
            border: Border.all(
              color: isSelected ? colors.goalSelectedBorder : colors.border,
              width: borderWidth,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: context.typo.tileLabel.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              if (hint != null)
                Text(
                  hint,
                  style: context.typo.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
