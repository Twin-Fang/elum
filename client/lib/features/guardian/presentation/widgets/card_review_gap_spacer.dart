import 'package:flutter/material.dart';

/// 순서 변경 줄 맨 끝의 틈: 카드가 줄 끝에 들어올 때만 카드 한 장 폭으로 열림
class CardReviewGapSpacer extends StatelessWidget {
  const CardReviewGapSpacer({
    super.key,
    required this.isOpen,
    required this.fullWidth,
    required this.slotDuration,
  });

  /// 열려야 하는가 (열림 정도만 애니메이션하고, 폭은 매 프레임 줌 비율을 따름)
  final bool isOpen;

  /// 열렸을 때의 폭
  final double fullWidth;
  final Duration slotDuration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: isOpen ? 1.0 : 0.0),
      duration: slotDuration,
      curve: Curves.easeOutCubic,
      builder: (context, openRatio, _) =>
          SizedBox(width: fullWidth * openRatio),
    );
  }
}
