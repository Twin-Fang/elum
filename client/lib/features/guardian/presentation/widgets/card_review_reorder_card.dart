import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../shared/models/action_card.dart';
import 'action_card_view.dart';

/// 순서 변경 모드의 카드 한 장: 카드 사이 간격만큼 가로 여백 + 읽기 전용 카드
/// 모드 안에서는 소리를 읽지 않고 삭제도 없음 (카드가 움직이는 중)
class CardReviewReorderCard extends StatelessWidget {
  const CardReviewReorderCard({
    super.key,
    required this.card,
    required this.index,
    required this.routineId,
    required this.language,
    required this.cardGap,
    this.liftStrength,
  });

  final ActionCard card;

  /// 색·번호를 정하는 자리 (안착한 뒤에 새 자리로 바뀜)
  final int index;
  final String routineId;
  final String language;
  final double cardGap;

  /// 손가락에 들린 카드의 그림자 세기(0~1). null 이면 그림자 없음
  final double? liftStrength;

  @override
  Widget build(BuildContext context) {
    final card = ActionCardView(
      key: ValueKey(this.card.id),
      card: this.card,
      index: index,
      routineId: routineId,
      language: language,
      onSpeak: () {},
      isSpeaking: false,
      onDelete: null,
    );
    final strength = liftStrength;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: (cardGap / 2).w),
      child: strength == null
          ? card
          : DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(context.space.cardRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.24 * strength),
                    blurRadius: 24 * strength,
                    offset: Offset(0, 10 * strength),
                  ),
                ],
              ),
              child: card,
            ),
    );
  }
}
