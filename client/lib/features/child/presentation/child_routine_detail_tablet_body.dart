import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/layout/layout_context_ext.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../shared/models/action_card.dart';
import '../../../shared/models/routine.dart';
import 'widgets/child_step_strip.dart';

/// 이룸이 카드 상세 태블릿 화면: 위 줄 > 순서 줄(단계·보상 목표) > 카드 한 장(꽉 채움, 체크 버튼은 카드 안) (#789)
///
/// 폰 배치(보상 칩 > 카드 > 아래 체크 버튼)는 상세 화면이 따로 그린다.
class ChildRoutineDetailTabletBody extends StatelessWidget {
  const ChildRoutineDetailTabletBody({
    super.key,
    required this.topBar,
    required this.routine,
    required this.currentIndex,
    required this.isChecked,
    required this.onStepTap,
    required this.pager,
  });

  final Widget topBar;

  /// 순서 줄의 단계·보상을 읽는 일과
  final Routine routine;
  final int currentIndex;
  final bool Function(ActionCard card) isChecked;
  final ValueChanged<int> onStepTap;

  /// 태블릿 카드 넘기기
  final Widget pager;

  /// 위 줄 > 순서 줄 > 카드 간격 (393 기준)
  static const _topBarToStrip = 12.0;
  static const _stripToCard = 20.0;

  /// 카드 넘기기가 양옆에 이미 두는 간격의 절반 (393 기준)
  static const _pagerHalfGap = 12.0;

  @override
  Widget build(BuildContext context) {
    final margin = context.layout.pageMarginFor(context.sizeClass).w;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 8.h),
            topBar,
            // 낮은 창(분할 보기 등)은 카드 자리를 위해 순서 줄을 접는다
            if (!context.layoutMetrics.isShortHeight) ...[
              SizedBox(height: _topBarToStrip.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: margin),
                child: ChildStepStrip(
                  cards: routine.steps,
                  currentIndex: currentIndex,
                  isChecked: isChecked,
                  onStepTap: onStepTap,
                  rewardEmoji: routine.hasReward ? routine.rewardEmoji : '',
                  rewardText: routine.hasReward ? routine.rewardText : '',
                  language: routine.language,
                ),
              ),
            ],
            SizedBox(height: _stripToCard.h),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: margin - _pagerHalfGap.w,
                ),
                child: pager,
              ),
            ),
            SizedBox(height: margin / 2),
          ],
        ),
      ),
    );
  }
}
