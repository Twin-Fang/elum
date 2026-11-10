import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_sheet_action_row.dart';
import '../../../../core/widgets/elum_sheet_frame.dart';
import '../../../../shared/models/action_card.dart';
import 'card_image.dart';
import 'default_card_art.dart';

/// 새 그림 고르기 시트: 지금 그림(또는 픽토그램) | 새 그림 나란히 > 지금 그림 그대로 · 새 그림으로 바꾸기
///
/// 고르기 전에는 카드 그림이 바뀌지 않음 (이룸이는 고른 그림만 봄). 내려 닫으면 지금 그림 그대로와 같음
class CardImageCandidateSheet extends StatelessWidget {
  const CardImageCandidateSheet({
    super.key,
    required this.routineId,
    required this.step,
    required this.candidateImageBytes,
  });

  final String routineId;
  final ActionCard step;
  final Uint8List candidateImageBytes;

  /// 새 그림으로 바꾸면 true, 지금 그림 그대로·내려 닫음이면 false
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

  /// 카드 그림 칸과 같은 비율 (Figma 313×230)
  static const _previewAspect = 313 / 230;

  /// 왼쪽 버튼 폭 (`지금 그림 그대로` 가 한 줄)
  static const _cancelButtonWidth = 150.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final space = context.space;

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
                child: _LabeledPreview(
                  label: l10n.cardCandidateCurrentLabel,
                  child: CardImage(
                    routineId: routineId,
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
                child: _LabeledPreview(
                  label: l10n.cardCandidateNewLabel,
                  child: Image.memory(
                    candidateImageBytes,
                    fit: BoxFit.cover,
                    semanticLabel: l10n.cardCandidateNewLabel,
                    errorBuilder: (_, _, _) => const DefaultCardPhotoSlot(),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: space.lg.h),
          ElumSheetActionRow(
            cancelLabel: l10n.cardCandidateKeepButton,
            onCancel: () => Navigator.of(context).pop(false),
            confirmLabel: l10n.cardCandidateApplyButton,
            onConfirm: () => Navigator.of(context).pop(true),
            // `지금 그림 그대로` 가 한 줄에 들어가게 넓힘
            cancelWidth: _cancelButtonWidth,
          ),
        ],
      ),
    );
  }
}

/// 이름 한 줄 > 카드 비율 그림 칸
class _LabeledPreview extends StatelessWidget {
  const _LabeledPreview({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: context.typo.settingsTileLabel.copyWith(color: colors.textPrimary),
        ),
        SizedBox(height: space.xs.h),
        AspectRatio(
          aspectRatio: CardImageCandidateSheet._previewAspect,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(space.xs),
            child: ColoredBox(color: colors.surface, child: child),
          ),
        ),
      ],
    );
  }
}
