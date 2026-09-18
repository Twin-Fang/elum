import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 보상 선택 칩 — 이모지 + 문구 (이슈 #239).
///
/// 목표 칩(`GoalChip`)과 생김새를 맞추되 **2열로 놓이므로 폭이 절반**이고,
/// 그림 자리에 이모지가 들어간다. 프리셋 그림 5종이 나오면 이모지를 SVG로
/// 갈아끼운다 (#198 D3 🎨 항목) — 그때 이 위젯 한 곳만 고치면 된다.
///
/// 선택 로직은 화면이 갖고, 이 위젯은 "어떻게 보이는가"만 책임진다.
class RewardChip extends StatelessWidget {
  const RewardChip({
    super.key,
    required this.emoji,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  /// 2열이라 목표 칩(68)보다 낮다. 글이 두 줄이 되어도 넘치지 않는 높이다.
  static const height = 60.0;

  /// 칩 사이 간격 (가로·세로 공통)
  static const gap = 12.0;

  static const _padH = 14.0;
  static const _emojiToLabel = 10.0;

  /// 이모지는 앱 폰트가 아니라 OS 폰트로 그려진다 — 타이포 토큰을 태우지 않는다.
  static const _emojiSize = 22.0;

  final String emoji;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        height: height.h,
        padding: EdgeInsets.symmetric(horizontal: _padH.w),
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
            Text(emoji, style: TextStyle(fontSize: _emojiSize.sp)),
            SizedBox(width: _emojiToLabel.w),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.typo.chipLabel.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
