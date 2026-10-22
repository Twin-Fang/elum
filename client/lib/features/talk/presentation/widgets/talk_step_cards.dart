import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../domain/talk_post.dart';
import 'talk_step_card.dart';

/// 상세 카드 묶음: 크게 보기(가로로 넘기기, 시안 1783:7172) | 한 눈에 보기(2열 격자, 시안 1813:7718)
/// 화면 폭을 꽉 채운다 (좌우 여백은 여기서 준다)
class TalkStepCards extends StatelessWidget {
  const TalkStepCards({
    super.key,
    required this.postId,
    required this.steps,
    required this.isGridView,
  });

  final String postId;
  final List<TalkStep> steps;
  final bool isGridView;

  /// 좌우 여백 · 크게 보기 카드 사이 (시안 16 · 10)
  static const _sideInset = 16.0;
  static const _largeGap = 10.0;

  /// 격자 칸 사이 가로 · 세로 (시안 9 · 8)
  static const _gridGapH = 9.0;
  static const _gridGapV = 8.0;
  static const _gridColumnCount = 2;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();
    return isGridView ? _grid() : _large();
  }

  /// 크게 보기: 카드 333 폭을 가로로 이어 붙여 넘긴다
  Widget _large() {
    final cardWidth = TalkStepCard.designWidth.w;
    final cardHeight =
        cardWidth * TalkStepCard.designHeight / TalkStepCard.designWidth;
    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: _sideInset.w),
        // 카드 그림자가 위아래로 잘리지 않게
        clipBehavior: Clip.none,
        itemCount: steps.length,
        separatorBuilder: (_, _) => SizedBox(width: _largeGap.w),
        itemBuilder: (context, index) => TalkStepCard.fromStep(
          postId: postId,
          step: steps[index],
          index: index,
          width: cardWidth,
        ),
      ),
    );
  }

  /// 한 눈에 보기: 같은 카드를 칸 폭으로 줄여 2열로
  Widget _grid() => Padding(
    padding: EdgeInsets.symmetric(horizontal: _sideInset.w),
    child: LayoutBuilder(
      builder: (context, constraints) {
        // 소수점이 남으면 Wrap 이 둘째 칸을 다음 줄로 넘긴다 (내림)
        final cellWidth =
            ((constraints.maxWidth - _gridGapH.w * (_gridColumnCount - 1)) /
                    _gridColumnCount)
                .floorToDouble();
        return Wrap(
          spacing: _gridGapH.w,
          runSpacing: _gridGapV.w,
          children: [
            for (var index = 0; index < steps.length; index++)
              TalkStepCard.fromStep(
                postId: postId,
                step: steps[index],
                index: index,
                width: cellWidth,
              ),
          ],
        );
      },
    ),
  );
}
