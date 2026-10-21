import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';
import 'guardian_tab.dart';
import 'guardian_tab_icon.dart';
import 'guardian_tab_pressable.dart';

/// 폰 보호자 하단 바: 아이콘 + 칸 이름 (시안 `네비게이션바` 1666:7082, #835)
///
/// 시안 높이 88 = 내용 56(위 12 · 아이콘 24 · 사이 6 · 이름 14) + 아래 32. 아래 32 중 홈 표시줄 여백만큼은 틀(shell)이 칠한다.
class GuardianBottomNav extends StatelessWidget {
  const GuardianBottomNav({
    super.key,
    required this.selectedTab,
    required this.onTabSelected,
  });

  final GuardianTab selectedTab;
  final ValueChanged<GuardianTab> onTabSelected;

  /// 위 선 두께 · 아이콘 위 여백 · 아이콘 한 변 · 아이콘과 이름 사이 · 이름 아래 여백 (시안 2 · 12 · 24 · 6 · 32)
  static const dividerWidth = 2.0;
  static const _topPadding = 12.0;
  static const _iconSize = 24.0;
  static const _iconLabelGap = 6.0;
  static const _designBottomPadding = 32.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // 홈 표시줄 여백이 시안 아래 32를 다 채우면 바 자체 아래 여백은 0
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomPadding = math.max(_designBottomPadding.h - bottomInset, 0.0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.navBackground,
        border: Border(
          top: BorderSide(color: colors.navDivider, width: dividerWidth),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final tab in GuardianTab.values)
              Expanded(
                child: _BottomNavItem(
                  tab: tab,
                  isSelected: tab == selectedTab,
                  onTap: () => onTabSelected(tab),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 하단 바 칸 하나 (누름 영역 = 칸 전체, 눌림 · 고름 동작은 아이콘만, 고른 칸 · 아닌 칸은 색만 다름)
class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  final GuardianTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final itemColor = isSelected
        ? colors.navIconSelected
        : colors.navItemUnselected;
    final label = tab.labelOf(context);
    return Semantics(
      selected: isSelected,
      child: GuardianTabPressable(
        onTap: onTap,
        semanticLabel: label,
        builder: (context, isPressed, selectionPlayCount) => Padding(
          padding: EdgeInsets.only(top: GuardianBottomNav._topPadding.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 정사각형 칸 — .w
              GuardianTabIcon(
                tab: tab,
                size: GuardianBottomNav._iconSize.w,
                color: itemColor,
                isPressed: isPressed,
                selectionPlayCount: selectionPlayCount,
              ),
              SizedBox(height: GuardianBottomNav._iconLabelGap.h),
              // 큰 글자에서도 한 줄 유지 (칸 폭을 넘으면 줄여서 맞춤)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: GuardianTabIcon.colorChangeDurationOf(context),
                  style: context.typo.bottomNavLabel.copyWith(color: itemColor),
                  child: Text(label, maxLines: 1, softWrap: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
