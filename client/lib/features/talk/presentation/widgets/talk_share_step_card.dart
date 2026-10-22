import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/models/action_card.dart';
import '../../domain/talk_preview.dart';
import 'talk_share_card_picture.dart';
import 'talk_step_card.dart';

/// 올리기 카드 한 장: 상세와 같은 시안 카드에 내 일과 카드 그림을 넣는다 (올라간 뒤 모습 그대로)
class TalkShareStepCard extends StatelessWidget {
  const TalkShareStepCard({
    super.key,
    required this.routineId,
    required this.step,
    required this.card,
    required this.index,
    required this.width,
    this.isBlurred = false,
  });

  final String routineId;
  final TalkPreviewStep step;

  /// 일과관리 목록에서 못 찾았으면 null
  final ActionCard? card;

  /// 색을 정하는 목록 순서 (0부터)
  final int index;
  final double width;
  final bool isBlurred;

  @override
  Widget build(BuildContext context) {
    final title = step.title ?? '';
    return TalkStepCard(
      picture: TalkShareCardPicture(
        routineId: routineId,
        card: card,
        label: title,
        isBlurred: isBlurred,
      ),
      cardNumber: step.cardNumber,
      title: title,
      description: step.description,
      index: index,
      width: width,
    );
  }
}

/// 2열 격자 (상세 한 눈에 보기와 같은 칸 사이 9 × 8): 칸 폭을 받아 칸마다 그린다
class TalkShareCardGrid extends StatelessWidget {
  const TalkShareCardGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.isCenteredWhenSingle = false,
  });

  final int itemCount;

  /// true 면 칸이 하나뿐일 때 가운데에 둔다 (사진 고르기)
  final bool isCenteredWhenSingle;
  final Widget Function(BuildContext context, int index, double cellWidth)
  itemBuilder;

  static const _gapH = 9.0;
  static const _gapV = 8.0;
  static const _columnCount = 2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 소수점이 남으면 Wrap 이 둘째 칸을 다음 줄로 넘긴다 (내림)
        final cellWidth =
            ((constraints.maxWidth - _gapH.w * (_columnCount - 1)) /
                    _columnCount)
                .floorToDouble();
        return Wrap(
          alignment: isCenteredWhenSingle && itemCount == 1
              ? WrapAlignment.center
              : WrapAlignment.start,
          spacing: _gapH.w,
          runSpacing: _gapV.w,
          children: [
            for (var index = 0; index < itemCount; index++)
              SizedBox(
                width: cellWidth,
                child: itemBuilder(context, index, cellWidth),
              ),
          ],
        );
      },
    );
  }
}
