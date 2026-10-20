import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../shared/models/action_card.dart';
import '../../domain/talk_preview.dart';
import 'talk_choice_row.dart';
import 'talk_share_step_card.dart';

/// 사진 고르기: 보호자 사진 카드마다 "흐리게 / 그대로" (기본값 없음)
/// 고른 카드는 바로 흐린 모습으로 미리 보인다
class TalkPhotoBlurPicker extends StatelessWidget {
  const TalkPhotoBlurPicker({
    super.key,
    required this.routineId,
    required this.photoSteps,
    required this.cardByStepId,
    required this.blurChoiceByStepId,
    required this.onChoose,
    this.isEnabled = true,
  });

  final String routineId;

  /// 보호자 사진 카드만
  final List<TalkPreviewStep> photoSteps;
  final Map<String, ActionCard> cardByStepId;

  /// null 이면 아직 고르지 않음
  final Map<String, bool?> blurChoiceByStepId;
  final void Function(String stepId, {required bool shouldBlur}) onChoose;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.talkSharePhotoTitle,
          style: typo.sectionTitle.copyWith(color: colors.textPrimary),
        ),
        SizedBox(height: space.xs.h),
        Text(
          l10n.talkSharePhotoGuide,
          style: typo.body.paragraph.copyWith(color: colors.textSecondary),
        ),
        SizedBox(height: space.md.h),
        for (final step in photoSteps) ...[
          TalkShareStepCard(
            routineId: routineId,
            step: step,
            card: cardByStepId[step.stepId],
            isBlurred: blurChoiceByStepId[step.stepId] == true,
            footer: Row(
              children: [
                Expanded(
                  child: TalkChoiceRow(
                    label: l10n.talkSharePhotoBlur,
                    isSelected: blurChoiceByStepId[step.stepId] == true,
                    onTap: isEnabled
                        ? () => onChoose(step.stepId, shouldBlur: true)
                        : null,
                  ),
                ),
                SizedBox(width: space.xs.w),
                Expanded(
                  child: TalkChoiceRow(
                    label: l10n.talkSharePhotoKeep,
                    isSelected: blurChoiceByStepId[step.stepId] == false,
                    onTap: isEnabled
                        ? () => onChoose(step.stepId, shouldBlur: false)
                        : null,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: space.sm.h),
        ],
      ],
    );
  }
}
