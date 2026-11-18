import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/layout/layout_context_ext.dart';

/// 카드 확인 가로 태블릿 두 칸 (#1457): 왼쪽 머리 · 넓은 카드가 칸을 채움 | 오른쪽 보상 · 도구 · 저장 (아래 맞춤)
/// 폰 · 세로 태블릿은 화면이 한 열로 그대로 그림
class CardReviewWideBody extends StatelessWidget {
  const CardReviewWideBody({
    super.key,
    required this.coachMark,
    required this.heading,
    required this.cards,
    required this.rewardRow,
    required this.toolRow,
    required this.saveButton,
  });

  /// 크기 0 코치마크 자리
  final Widget coachMark;

  /// 제목 · 안내 (· 메모리 알약)
  final Widget heading;

  /// 카드 넘기기 (또는 순서 변경 목록)
  final Widget cards;
  final Widget rewardRow;
  final Widget toolRow;
  final Widget saveButton;

  /// 칸 위 · 머리 > 카드 · 오른쪽 줄 사이 · 아래 여백 (393 기준)
  static const _paneTop = 12.0;
  static const _headingToCards = 16.0;
  static const _rowGap = 20.0;
  static const _paneBottom = 24.0;

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final pageMargin = layout.pageMarginFor(context.sizeClass).w;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: pageMargin),
        Expanded(
          child: Column(
            children: [
              coachMark,
              SizedBox(height: _paneTop.h),
              heading,
              SizedBox(height: _headingToCards.h),
              Expanded(child: cards),
              SizedBox(height: _paneBottom.h),
            ],
          ),
        ),
        SizedBox(width: layout.paneGutter.w),
        // 오른쪽 칸: 도구 줄 폭 그대로, 아래로 모아 엄지가 닿는 자리
        SizedBox(
          width: layout.masterPaneWidth.w,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              rewardRow,
              SizedBox(height: _rowGap.h),
              toolRow,
              SizedBox(height: _rowGap.h),
              saveButton,
              SizedBox(height: _paneBottom.h),
            ],
          ),
        ),
        SizedBox(width: pageMargin),
      ],
    );
  }
}
