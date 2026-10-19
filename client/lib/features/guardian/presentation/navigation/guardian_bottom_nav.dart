import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import 'guardian_tab.dart';

/// 폰 보호자 하단 바: 아이콘만, 얇게 (#798 시안 P1)
///
/// 고른 칸 = 꽉 찬 진한 아이콘, 나머지 = 선 회색 아이콘. 칸 이름은 화면 낭독 이름으로만 둔다.
class GuardianBottomNav extends StatelessWidget {
  const GuardianBottomNav({
    super.key,
    required this.selectedTab,
    required this.onTabSelected,
  });

  final GuardianTab selectedTab;
  final ValueChanged<GuardianTab> onTabSelected;

  /// 바 높이 · 아이콘 한 변 (시안 50 · 26)
  static const barHeight = 50.0;
  static const _iconSize = 26.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.navBackground,
        border: Border(top: BorderSide(color: colors.navDivider)),
      ),
      child: SizedBox(
        height: barHeight.h,
        child: Row(
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

/// 하단 바 칸 하나 (누름 영역 = 칸 전체)
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
    return Semantics(
      selected: isSelected,
      child: AppPressable(
        onTap: onTap,
        scaleDown: AppPressable.scaleIcon,
        semanticLabel: tab.labelOf(context),
        child: Center(
          child: Icon(
            isSelected ? tab.selectedIcon : tab.icon,
            // 정사각형 아이콘 — .w
            size: GuardianBottomNav._iconSize.w,
            color: isSelected
                ? colors.navIconSelected
                : colors.navIconUnselected,
          ),
        ),
      ),
    );
  }
}
