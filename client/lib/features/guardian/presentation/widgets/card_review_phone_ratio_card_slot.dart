import 'package:flutter/material.dart';

import '../../../../core/theme/card_layout.dart';

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
