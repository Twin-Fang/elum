import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_spinner.dart';
import 'action_card_delete_button.dart';
import 'card_image.dart';

class ActionCardIllustration extends StatelessWidget {
  const ActionCardIllustration({
    super.key,
    required this.routineId,
    required this.stepId,
    this.imagePath,
    this.pictogramId,
    this.exampleImageId,
    this.pictogramLabel = '',
    required this.emptyBuilder,
    this.onDelete,
    this.isImageGenerating = false,
  });

  final String routineId;
  final String stepId;
  final String? imagePath;
  final String? pictogramId;
  final String? exampleImageId;
  final String pictogramLabel;
  final WidgetBuilder emptyBuilder;
  final VoidCallback? onDelete;

  /// 그림을 그리는 중이면 그림칸 위에 진행 표시 (#868)
  final bool isImageGenerating;

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
                exampleImageId: exampleImageId,
                pictogramLabel: pictogramLabel,
                emptyBuilder: emptyBuilder,
              ),
            ),
          ),
        ),
        if (isImageGenerating)
          Positioned.fill(child: _ImageGeneratingOverlay(radius: space.xs)),
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

/// 그림 만드는 중 표시: 그림칸을 덮고 진행 원 + 안내 한 줄
class _ImageGeneratingOverlay extends StatelessWidget {
  const _ImageGeneratingOverlay({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElumSpinner(size: 32.w, color: colors.textSecondary),
            SizedBox(height: space.sm),
            Text(
              context.l10n.cardImageGeneratingLabel,
              style: context.typo.caption.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
