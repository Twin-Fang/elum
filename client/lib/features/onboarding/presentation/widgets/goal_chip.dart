import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../domain/support_goal.dart';

/// 도움 목표 선택 항목. 아이콘 + 문구.
///
/// 선택 로직은 SelectableGroup이 갖고, 이 위젯은 "어떻게 보이는가"만 책임진다.
class GoalChip extends StatelessWidget {
  const GoalChip({
    super.key,
    required this.goal,
    required this.isSelected,
  });

  final SupportGoal goal;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return AnimatedContainer(
      // 아동도 볼 수 있는 화면이라 전환을 급하게 두지 않는다
      duration: const Duration(milliseconds: 200),
      margin: EdgeInsets.only(bottom: space.sm),
      padding: EdgeInsets.symmetric(horizontal: space.md, vertical: space.md),
      decoration: BoxDecoration(
        color: isSelected ? colors.selectedFill : colors.surface,
        borderRadius: BorderRadius.circular(space.cardRadius),
        border: Border.all(
          color: isSelected ? colors.selectedBorder : colors.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          SvgPicture.asset(AppAssets.goalIcon(goal), width: 40, height: 40),
          SizedBox(width: space.sm),
          Expanded(
            child: Text(
              goal.label,
              style: context.typo.body.copyWith(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
