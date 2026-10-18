import 'package:flutter/material.dart';

import '../../../../shared/models/action_card.dart';
import 'card_review_reorder_card.dart';

/// 손가락을 따라다니는 카드: 이웃보다 조금 크게 그리고 그림자를 깖
/// [strength] 0~1 이 클수록 그림자가 짙고 넓음 (집은 정도)
class CardReviewDragOverlay extends StatelessWidget {
  const CardReviewDragOverlay({
    super.key,
    required this.card,
    required this.index,
    required this.routineId,
    required this.language,
    required this.cardGap,
    required this.topLeft,
    required this.width,
    required this.height,
    required this.scale,
    required this.strength,
  });

  final ActionCard card;
  final int index;
  final String routineId;
  final String language;
  final double cardGap;
  final Offset topLeft;
  final double width;
  final double height;
  final double scale;
  final double strength;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      width: width,
      height: height,
      child: IgnorePointer(
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topLeft,
          child: CardReviewReorderCard(
            card: card,
            index: index,
            routineId: routineId,
            language: language,
            cardGap: cardGap,
            liftStrength: strength,
          ),
        ),
      ),
    );
  }
}
