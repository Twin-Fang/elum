import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_choice_chip.dart';
import '../../application/lock_screen_providers.dart';

/// 띄우는 간격 고르기: 제목 > 알약 칩 4개 (켤 때마다 · 30분 · 1시간 · 3시간)
class LockScreenIntervalPicker extends StatelessWidget {
  const LockScreenIntervalPicker({
    super.key,
    required this.selectedIntervalMinutes,
    required this.onSelected,
  });

  final int selectedIntervalMinutes;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.lockScreenIntervalTitle,
          style: context.typo.creditTitle.copyWith(
            color: context.colors.textPrimary,
          ),
        ),
        SizedBox(height: space.xs.h),
        Wrap(
          spacing: space.xs.w,
          runSpacing: space.xs.h,
          children: [
            for (final intervalMinutes in lockScreenIntervalOptions)
              ElumChoiceChip(
                label: toLockScreenIntervalLabel(context, intervalMinutes),
                isSelected: intervalMinutes == selectedIntervalMinutes,
                onTap: () => onSelected(intervalMinutes),
              ),
          ],
        ),
      ],
    );
  }
}

/// 간격(분) > 표시 이름 (0 켤 때마다, 60의 배수는 시간, 그 밖은 분)
String toLockScreenIntervalLabel(BuildContext context, int intervalMinutes) =>
    switch (intervalMinutes) {
      0 => context.l10n.lockScreenIntervalEveryTime,
      _ when intervalMinutes % 60 == 0 => context.l10n.lockScreenIntervalHours(
        intervalMinutes ~/ 60,
      ),
      _ => context.l10n.lockScreenIntervalMinutes(intervalMinutes),
    };
