import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../layout/layout_context_ext.dart';
import '../layout/window_size_class.dart';
import '../theme/theme_context_ext.dart';
import 'app_pressable.dart';

/// 탭 한 칸: 글자와 (선택) 빨간 점
@immutable
class ElumTab {
  const ElumTab({required this.label, this.hasDot = false});

  final String label;

  /// 안 읽은 것이 있다는 빨간 점
  final bool hasDot;
}

/// 화면 위쪽 N칸 탭: 같은 폭으로 나누고 고른 칸 아래에 밑줄, 칸마다 빨간 점을 달 수 있음
class ElumSegmentedTabs extends StatelessWidget {
  const ElumSegmentedTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<ElumTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// 칸 높이: 폰 48, 태블릿 56
  static const _compactHeight = 48.0;
  static const _wideHeight = 56.0;

  /// 점 지름과 글자와의 간격
  static const _dotSize = 8.0;
  static const _dotGap = 6.0;

  /// 밑줄 두께 (고른 칸 2, 나머지 칸 아래는 구분선 1)
  static const _selectedUnderlineThickness = 2.0;
  static const _dividerThickness = 1.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final height = (context.sizeClass == WindowSizeClass.compact
            ? _compactHeight
            : _wideHeight)
        .h;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.border, width: _dividerThickness),
        ),
      ),
      child: Row(
        children: [
          for (var index = 0; index < tabs.length; index++)
            Expanded(
              child: _TabCell(
                tab: tabs[index],
                isSelected: index == selectedIndex,
                height: height,
                onTap: () => onSelected(index),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabCell extends StatelessWidget {
  const _TabCell({
    required this.tab,
    required this.isSelected,
    required this.height,
    required this.onTap,
  });

  final ElumTab tab;
  final bool isSelected;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final labelColor = isSelected ? colors.textPrimary : colors.textSecondary;

    return Semantics(
      selected: isSelected,
      child: AppPressable(
        onTap: isSelected ? null : onTap,
        scaleDown: AppPressable.scaleCard,
        child: SizedBox(
          height: height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      tab.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typo.navTitle.copyWith(color: labelColor),
                    ),
                  ),
                  if (tab.hasDot) ...[
                    SizedBox(width: ElumSegmentedTabs._dotGap.w),
                    Container(
                      width: ElumSegmentedTabs._dotSize.w,
                      height: ElumSegmentedTabs._dotSize.w,
                      decoration: BoxDecoration(
                        color: colors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              if (isSelected)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: ElumSegmentedTabs._selectedUnderlineThickness,
                    color: colors.textPrimary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
