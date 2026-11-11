import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/elum_check_circle.dart';
import '../../../../core/widgets/elum_label_chip.dart';
import '../../../../core/widgets/elum_sheet_frame.dart';
import '../../../../shared/models/action_card.dart';
import 'card_image.dart';
import 'default_card_art.dart';

/// 새 그림 고르기 시트: 지금 그림 | 새 그림 중 하나를 눌러 고름 > `이 그림으로 하기` 버튼 하나
///
/// 처음에는 새 그림이 골라져 있음. 고르기 전에는 카드 그림이 바뀌지 않음 (이룸이는 고른 그림만 봄). 내려 닫으면 지금 그림 그대로
class CardImageCandidateSheet extends StatefulWidget {
  const CardImageCandidateSheet({
    super.key,
    required this.routineId,
    required this.step,
    required this.candidateImageBytes,
  });

  final String routineId;
  final ActionCard step;
  final Uint8List candidateImageBytes;

  /// 새 그림을 골랐으면 true, 지금 그림을 골랐거나 내려 닫았으면 false
  static Future<bool> show(
    BuildContext context, {
    required String routineId,
    required ActionCard step,
    required Uint8List candidateImageBytes,
  }) async {
    final isApplied = await showElumSheet<bool>(
      context: context,
      builder: (_) => CardImageCandidateSheet(
        routineId: routineId,
        step: step,
        candidateImageBytes: candidateImageBytes,
      ),
    );
    return isApplied ?? false;
  }

  @override
  State<CardImageCandidateSheet> createState() => _CardImageCandidateSheetState();
}

class _CardImageCandidateSheetState extends State<CardImageCandidateSheet> {
  bool _isNewSelected = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final space = context.space;
    final step = widget.step;

    return ElumSheetFrame(
      title: l10n.cardCandidateSheetTitle,
      description: l10n.cardCandidateSheetBody,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SelectablePreview(
                  label: l10n.cardCandidateCurrentLabel,
                  isSelected: !_isNewSelected,
                  onTap: () => setState(() => _isNewSelected = false),
                  child: CardImage(
                    routineId: widget.routineId,
                    stepId: step.id,
                    imagePath: step.imagePath,
                    pictogramId: step.pictogramId,
                    exampleImageId: step.exampleImageId,
                    pictogramLabel: step.displayTitle,
                    emptyBuilder: (_) => const DefaultCardPhotoSlot(),
                  ),
                ),
              ),
              SizedBox(width: space.sm.w),
              Expanded(
                child: _SelectablePreview(
                  label: l10n.cardCandidateNewLabel,
                  isSelected: _isNewSelected,
                  onTap: () => setState(() => _isNewSelected = true),
                  child: Image.memory(
                    widget.candidateImageBytes,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => const DefaultCardPhotoSlot(),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: space.lg.h),
          ElumButton(
            label: l10n.cardCandidateSelectButton,
            onPressed: () => Navigator.of(context).pop(_isNewSelected),
          ),
        ],
      ),
    );
  }
}

/// 고를 수 있는 그림 칸: 카드 비율 그림 + 왼쪽 위 이름 칩 + 오른쪽 위 체크, 고르면 굵은 테두리
class _SelectablePreview extends StatelessWidget {
  const _SelectablePreview({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget child;

  /// 카드 그림 칸과 같은 비율 (Figma 313×230)
  static const _previewAspect = 313 / 230;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final borderWidth = isSelected ? space.selectedBorderWidth : space.borderWidth;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: isSelected,
      child: AppPressable(
        onTap: onTap,
        semanticLabel: label,
        child: AspectRatio(
          aspectRatio: _previewAspect,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(space.cardRadius.r),
              border: Border.all(color: isSelected ? colors.goalSelectedBorder : colors.border, width: borderWidth),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                child,
                Positioned(
                  left: space.xs.w,
                  top: space.xs.h,
                  child: ElumLabelChip(label: label, background: colors.editChipBg, foreground: colors.textPrimary),
                ),
                Positioned(
                  right: space.xs.w,
                  top: space.xs.h,
                  child: ElumCheckCircle(isChecked: isSelected),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
