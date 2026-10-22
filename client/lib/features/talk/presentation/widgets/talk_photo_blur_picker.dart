import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../shared/models/action_card.dart';
import '../../domain/talk_preview.dart';
import 'talk_category_chips.dart';
import 'talk_page_heading.dart';
import 'talk_share_step_card.dart';

/// 사진 고르기: 보호자 사진 카드마다 "흐리게 / 그대로" 알약 칩 (기본값 없음)
/// 2열 격자 칸마다 카드 > 칩 둘. 고르면 카드 그림이 바로 흐려진다
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

  /// 머리 > 격자 · 카드 > 칩 · 칩 사이
  static const _headingToGrid = 24.0;
  static const _cardToChips = 10.0;
  static const _chipGap = 6.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TalkPageHeading(
          title: l10n.talkSharePhotoTitle,
          description: l10n.talkSharePhotoGuide,
        ),
        SizedBox(height: _headingToGrid.h),
        TalkShareCardGrid(
          itemCount: photoSteps.length,
          isCenteredWhenSingle: true,
          itemBuilder: (context, index, cellWidth) {
            final step = photoSteps[index];
            final choice = blurChoiceByStepId[step.stepId];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TalkShareStepCard(
                  routineId: routineId,
                  step: step,
                  card: cardByStepId[step.stepId],
                  // 색 판은 카드 순서를 따른다 (stepOrder 는 1부터)
                  index: step.stepOrder - 1,
                  width: cellWidth,
                  isBlurred: choice == true,
                ),
                SizedBox(height: _cardToChips.h),
                Row(
                  children: [
                    Expanded(
                      child: TalkCategoryChip(
                        label: l10n.talkSharePhotoBlur,
                        isSelected: choice == true,
                        isExpanded: true,
                        onTap: isEnabled
                            ? () => onChoose(step.stepId, shouldBlur: true)
                            : null,
                      ),
                    ),
                    SizedBox(width: _chipGap.w),
                    Expanded(
                      child: TalkCategoryChip(
                        label: l10n.talkSharePhotoKeep,
                        isSelected: choice == false,
                        isExpanded: true,
                        onTap: isEnabled
                            ? () => onChoose(step.stepId, shouldBlur: false)
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
