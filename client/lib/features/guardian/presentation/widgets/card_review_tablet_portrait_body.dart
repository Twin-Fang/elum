import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/layout/layout_context_ext.dart';

/// 카드 확인 세로 태블릿 한 열 (#1457): 머리 > 폰 비율 카드 크게 > 점 > 보상 > 큰 도구 한 줄 > 저장 (가운데 폭 상한)
class CardReviewTabletPortraitBody extends StatelessWidget {
  const CardReviewTabletPortraitBody({
    super.key,
    required this.coachMark,
    required this.heading,
    required this.cards,
    required this.rewardRow,
    required this.toolRow,
    required this.saveButton,
    this.pageDots,
  });

  final Widget coachMark;
  final Widget heading;
  final Widget cards;
  final Widget rewardRow;
  final Widget toolRow;
  final Widget saveButton;
  final Widget? pageDots;

  /// 칸 위 · 머리 > 카드 · 카드 > 점 · 줄 사이 · 아래 여백 (393 기준)
  static const _paneTop = 12.0;
  static const _headingToCards = 16.0;
  static const _cardsToDots = 12.0;
  static const _rowGap = 16.0;
  static const _paneBottom = 24.0;

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: layout.contentColumnMaxWidth.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            coachMark,
            SizedBox(height: _paneTop.h),
            heading,
            SizedBox(height: _headingToCards.h),
            Expanded(child: cards),
            if (pageDots case final dots?) ...[SizedBox(height: _cardsToDots.h), Center(child: dots)],
            SizedBox(height: _rowGap.h),
            rewardRow,
            SizedBox(height: _rowGap.h),
            toolRow,
            SizedBox(height: _rowGap.h),
            saveButton,
            SizedBox(height: _paneBottom.h),
          ],
        ),
      ),
    );
  }
}
