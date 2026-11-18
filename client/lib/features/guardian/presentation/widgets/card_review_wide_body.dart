import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/layout/layout_context_ext.dart';
import '../../../../core/theme/card_layout.dart';

/// 카드 확인 가로 태블릿 두 칸 (#1457): 왼쪽 머리 · 폰 비율 카드 크게 · 점 | 오른쪽 보상 · 큰 도구 2×2 · 저장 (아래 맞춤)
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
    this.pageDots,
  });

  /// 카드 아래 몇 번째인지 점 (순서 변경 중엔 없음)
  final Widget? pageDots;

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
  static const _cardsToDots = 12.0;

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
              if (pageDots case final dots?) ...[SizedBox(height: _cardsToDots.h), dots],
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

/// 태블릿 카드 한 장: 폰 카드 비율(333 : 410) 그대로 칸에 맞는 가장 큰 크기로 가운데 (#1457)
class CardReviewPhoneRatioCardSlot extends StatelessWidget {
  const CardReviewPhoneRatioCardSlot({super.key, required this.child});

  final Widget child;

  /// 폰 시안 카드 333 × 410 (카드 y161 ~ 571)
  static const _phoneCardHeight = 410.0;
  static const _cardAspect = CardLayout.cardWidth / _phoneCardHeight;

  @override
  Widget build(BuildContext context) => Center(
    child: AspectRatio(aspectRatio: _cardAspect, child: child),
  );
}

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
