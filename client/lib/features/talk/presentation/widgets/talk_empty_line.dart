import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_fade_slide_in.dart';

/// 이야기 빈 상태 줄 (홈 빈 상태 결 217:2655 — 361×68 웜그레이 r20): 그림·버튼 없이 글만, 목록 첫 줄 자리
/// 피드 0건 · 내려간 글 · 숨긴 보호자 0명이 함께 쓴다
class TalkEmptyLine extends StatelessWidget {
  const TalkEmptyLine({super.key, required this.title});

  final String title;

  /// 일과 한 줄과 같은 높이 (글자가 커지면 늘어난다) · 글 시작 (홈 일과 줄 왼쪽 18)
  static const _minHeight = 68.0;
  static const _padH = 18.0;

  /// 큰 글자에서 위아래가 판에 붙지 않는 여백
  static const _padV = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppFadeSlideIn(
      offset: 8,
      child: Container(
        constraints: BoxConstraints(minHeight: _minHeight.h),
        padding: EdgeInsets.symmetric(horizontal: _padH.w, vertical: _padV.h),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: colors.routineTileBg,
          borderRadius: BorderRadius.circular(context.space.cardRadius.r),
        ),
        child: Text(
          title,
          style: context.typo.routineEmptyTitle.copyWith(
            color: colors.routineTileLabel,
          ),
        ),
      ),
    );
  }
}
