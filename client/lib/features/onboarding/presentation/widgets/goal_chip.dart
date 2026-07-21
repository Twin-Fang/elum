import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../domain/support_goal.dart';

/// 도움 목표 선택 항목. 아이콘 + 문구.
///
/// Figma `온보딩_목표`(204:1002) / `온보딩_목표_선택`(204:1147) 기준:
/// 칩 344×68 r20, 아이콘 40×40 @x=38, 텍스트 @x=90.
/// 칩 좌측이 x=24이므로 내부 여백은 아이콘 14, 아이콘~텍스트 12다.
///
/// 선택 로직은 SelectableGroup이 갖고, 이 위젯은 "어떻게 보이는가"만 책임진다.
class GoalChip extends StatelessWidget {
  const GoalChip({
    super.key,
    required this.goal,
    required this.isSelected,
  });

  /// Figma 실측 — 칩 높이 68 고정
  static const height = 68.0;

  /// 아이콘과 칩 좌측 사이 여백 (38 - 24)
  static const _iconLeft = 14.0;

  /// 아이콘과 텍스트 사이 여백 (90 - 38 - 40)
  static const _iconToText = 12.0;

  static const _iconSize = 40.0;

  final SupportGoal goal;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AnimatedContainer(
      // 아동도 볼 수 있는 화면이라 전환을 급하게 두지 않는다
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: _iconLeft),
      decoration: BoxDecoration(
        color: isSelected ? colors.goalSelectedFill : colors.surface,
        borderRadius: BorderRadius.circular(context.space.cardRadius),
        border: Border.all(
          color: isSelected ? colors.goalSelectedBorder : colors.border,
          width: isSelected
              ? context.space.selectedBorderWidth
              : context.space.borderWidth,
        ),
      ),
      child: Row(
        children: [
          // 아이콘 배경 원은 선택 여부와 무관하게 동일하다 (Figma 확인)
          SvgPicture.asset(
            AppAssets.goalIcon,
            width: _iconSize,
            height: _iconSize,
          ),
          const SizedBox(width: _iconToText),
          Expanded(
            child: Text(
              goal.label,
              // Figma는 #000000이다. textPrimary(#242634)가 아니다.
              style: context.typo.body.copyWith(color: colors.chipLabel),
            ),
          ),
        ],
      ),
    );
  }
}
