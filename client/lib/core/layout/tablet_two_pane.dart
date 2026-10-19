import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'layout_context_ext.dart';

/// 가로 태블릿 두 칸 틀: 왼쪽(소개·장면) + 오른쪽(목록), 바깥 여백과 칸 사이 간격은 레이아웃 토큰
///
/// 왼쪽 폭은 [leadingWidth] 고정 또는 [leadingFlex]:[trailingFlex] 비율. 두 칸은 각자 높이를 꽉 채우고,
/// 스크롤은 칸 안의 자식이 정한다 (목록 칸만 스크롤 등).
class TabletTwoPane extends StatelessWidget {
  const TabletTwoPane({
    super.key,
    required this.leadingPane,
    required this.trailingPane,
    this.leadingWidth,
    this.leadingFlex = 5,
    this.trailingFlex = 6,
  });

  final Widget leadingPane;
  final Widget trailingPane;

  /// 왼쪽 칸 고정 폭 (393 기준, `.w` 전). null 이면 비율로 나눈다
  final double? leadingWidth;
  final int leadingFlex;
  final int trailingFlex;

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final margin = layout.pageMarginFor(context.sizeClass).w;
    final gutter = layout.paneGutter.w;
    final fixedWidth = leadingWidth;

    final leading = Padding(
      padding: EdgeInsets.only(left: margin),
      child: leadingPane,
    );
    final trailing = Padding(
      padding: EdgeInsets.only(right: margin),
      child: trailingPane,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (fixedWidth != null)
          SizedBox(width: fixedWidth.w + margin, child: leading)
        else
          Expanded(flex: leadingFlex, child: leading),
        SizedBox(width: gutter),
        Expanded(flex: trailingFlex, child: trailing),
      ],
    );
  }
}
