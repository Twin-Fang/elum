import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/date_labels.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 요일 7칸 고르기 (월 ~ 일): 고름 = 남색 채움 + 흰 글, 안 고름 = 웜그레이 + 남색 글 (칩 고르기 결)
///
/// 칸은 폭을 7등분한 원 (좁은 폰에서도 한 줄). 여러 개를 고를 수 있다.
class RoutineScheduleWeekdayPicker extends StatelessWidget {
  const RoutineScheduleWeekdayPicker({
    super.key,
    required this.selectedWeekdays,
    required this.onToggle,
  });

  /// `DateTime.weekday` 값(1=월 … 7=일)
  final Set<int> selectedWeekdays;

  /// null 이면 누를 수 없음 (저장 중)
  final ValueChanged<int>? onToggle;

  /// 칸 사이
  static const _gap = 6.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return Row(
      children: [
        for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) ...[
          if (weekday != DateTime.monday) SizedBox(width: _gap.w),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: _WeekdayCell(
                label: l10n.weekdayShortOfNumber(weekday),
                isSelected: selectedWeekdays.contains(weekday),
                selectedBackground: colors.textPrimary,
                selectedForeground: colors.surface,
                background: colors.routineTileBg,
                foreground: colors.textPrimary,
                onTap: onToggle == null ? null : () => onToggle!(weekday),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _WeekdayCell extends StatelessWidget {
  const _WeekdayCell({
    required this.label,
    required this.isSelected,
    required this.selectedBackground,
    required this.selectedForeground,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color selectedBackground;
  final Color selectedForeground;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: AppPressable(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? selectedBackground : background,
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              style: context.typo.chipLabel.copyWith(
                color: isSelected ? selectedForeground : foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
