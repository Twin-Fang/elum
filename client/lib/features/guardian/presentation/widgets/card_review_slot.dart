import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../shared/models/action_card.dart';

/// 순서 변경 줄의 카드 한 칸: 길게 눌러 집기 + 접근성 이동 동작 + 열리고 닫히는 폭
/// 집힌 카드의 칸은 닫히고, 들어올 자리 앞 칸은 카드 한 장 폭만큼 더 벌어짐
class CardReviewSlot extends StatelessWidget {
  const CardReviewSlot({
    super.key,
    required this.card,
    required this.index,
    required this.cardCount,
    required this.extent,
    required this.scale,
    required this.height,
    required this.isDragged,
    required this.isLanding,
    required this.hasGapBefore,
    required this.slotDuration,
    required this.cardBody,
    required this.onGrab,
    required this.onMove,
    required this.onDrop,
    required this.onCancel,
    required this.onNudge,
  });

  final ActionCard card;
  final int index;
  final int cardCount;

  /// 카드 한 장이 차지하는 가로 폭 (줌아웃 전)
  final double extent;
  final double scale;
  final double height;

  /// 지금 손가락에 집힌 카드인가
  final bool isDragged;

  /// 안착하는 중인가 (집힌 카드의 칸이 다시 열림)
  final bool isLanding;
  final bool hasGapBefore;
  final Duration slotDuration;
  final Widget cardBody;
  final void Function(LongPressStartDetails details) onGrab;
  final void Function(LongPressMoveUpdateDetails details) onMove;
  final VoidCallback onDrop;
  final VoidCallback onCancel;

  /// 접근성 이동: 앞으로 -1, 뒤로 +1
  final void Function(int delta) onNudge;

  @override
  Widget build(BuildContext context) {
    // 끌려간 카드의 자리는 닫힌다. 안착하는 동안은 다시 열려 카드가 들어올 자리가 된다.
    final open = (isDragged && !isLanding) ? 0.0 : 1.0;
    final canMove = cardCount > 1;

    Widget child = GestureDetector(
      onLongPressStart: onGrab,
      onLongPressMoveUpdate: onMove,
      onLongPressEnd: (_) => onDrop(),
      onLongPressCancel: onCancel,
      child: isDragged
          // 들린 카드는 위에 떠 있다. 자리에는 아무것도 그리지 않는다.
          ? const SizedBox.shrink()
          : SizedBox(
              width: extent * scale,
              height: height * scale,
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(width: extent, height: height, child: cardBody),
              ),
            ),
    );

    if (canMove) {
      final l10n = context.l10n;
      child = Semantics(
        customSemanticsActions: {
          if (index > 0)
            CustomSemanticsAction(label: l10n.cardMoveForward): () =>
                onNudge(-1),
          if (index < cardCount - 1)
            CustomSemanticsAction(label: l10n.cardMoveBackward): () =>
                onNudge(1),
        },
        child: child,
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(end: open + (hasGapBefore ? 1 : 0)),
      duration: slotDuration,
      curve: Curves.easeOutCubic,
      builder: (context, f, content) => SizedBox(
        width: extent * scale * f,
        // 카드는 자리의 오른쪽 끝에 붙는다 — 벌어진 틈이 카드 **앞**에 생긴다
        child: Align(alignment: Alignment.centerRight, child: content),
      ),
      child: child,
    );
  }
}
