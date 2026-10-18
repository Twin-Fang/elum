import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';
import 'action_card_delete_button.dart';
import 'card_image.dart';

class ActionCardIllustration extends StatelessWidget {
  const ActionCardIllustration({
    super.key,
    required this.routineId,
    required this.stepId,
    this.imagePath,
    this.pictogramId,
    this.pictogramLabel = '',
    required this.emptyBuilder,
    this.onDelete,
  });

  final String routineId;
  final String stepId;
  final String? imagePath;
  final String? pictogramId;
  final String pictogramLabel;
  final WidgetBuilder emptyBuilder;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(space.xs),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(space.xs),
              child: CardImage(
                routineId: routineId,
                stepId: stepId,
                imagePath: imagePath,
                pictogramId: pictogramId,
                pictogramLabel: pictogramLabel,
                emptyBuilder: emptyBuilder,
              ),
            ),
          ),
        ),
        // 지우기 원(30)은 그림칸 위·오른쪽에서 6 안쪽이다 (시안 `262:5124` 그림칸
        // 40,213 · 원 317,219). 누름 영역(44)이 원보다 7씩 넓어 그만큼 뺀다.
        if (onDelete != null)
          Positioned(
            top:
                ActionCardDeleteButton.designInset.w -
                ActionCardDeleteButton.touchPad.w,
            right:
                ActionCardDeleteButton.designInset.w -
                ActionCardDeleteButton.touchPad.w,
            child: ActionCardDeleteButton(onTap: onDelete!),
          ),
      ],
    );
  }
}
