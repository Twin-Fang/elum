import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_multiline_text_field.dart';
import '../../../../shared/models/action_card.dart';
import '../../../guardian/domain/routine_template.dart';
import '../../domain/talk_preview.dart';
import '../../domain/talk_text_limits.dart';
import 'talk_category_picker.dart';
import 'talk_share_step_card.dart';

/// 올리기 마지막 단계: 한마디(300자) > 분류 > 이름을 가린 카드 미리보기
class TalkShareDetailsForm extends StatelessWidget {
  const TalkShareDetailsForm({
    super.key,
    required this.routineId,
    required this.preview,
    required this.cardByStepId,
    required this.blurChoiceByStepId,
    required this.noteController,
    required this.category,
    required this.onNoteChanged,
    required this.onCategorySelected,
    this.isEnabled = true,
  });

  final String routineId;
  final TalkPreview preview;
  final Map<String, ActionCard> cardByStepId;

  /// 흐리게를 고른 카드는 미리보기에서도 흐리게 보인다
  final Map<String, bool?> blurChoiceByStepId;
  final TextEditingController noteController;
  final RoutineTemplateCategory? category;
  final ValueChanged<String> onNoteChanged;
  final ValueChanged<RoutineTemplateCategory> onCategorySelected;

  /// false 면 입력을 잠근다 (올리는 중)
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
          preview.title,
          style: typo.sectionTitle.copyWith(
            color: colors.textPrimary,
            height: 1.3,
          ),
        ),
        SizedBox(height: space.md.h),
        // 한마디 (글자 수 카운터)
        Text(
          l10n.talkNoteLabel,
          style: typo.tileLabel.copyWith(color: colors.textPrimary),
        ),
        SizedBox(height: space.xs.h),
        ElumMultilineTextField(
          controller: noteController,
          hintText: l10n.talkNoteGuide,
          maxLength: TalkTextLimits.maxNoteLength,
          minLines: 3,
          maxLines: 6,
          enabled: isEnabled,
          onChanged: onNoteChanged,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(top: space.xs.h),
            child: Text(
              '${noteController.text.length}/${TalkTextLimits.maxNoteLength}',
              style: typo.caption.copyWith(color: colors.textSecondary),
            ),
          ),
        ),
        SizedBox(height: space.sm.h),
        // 분류
        Text(
          l10n.talkCategoryTitle,
          style: typo.tileLabel.copyWith(color: colors.textPrimary),
        ),
        SizedBox(height: space.xs.h),
        TalkCategoryPicker(
          selectedCategory: category,
          isEnabled: isEnabled,
          onSelected: onCategorySelected,
        ),
        SizedBox(height: space.sm.h),
        // 이름을 가린 카드 미리보기
        Text(
          l10n.talkSharePreviewTitle,
          style: typo.cardTitle.copyWith(color: colors.textPrimary),
        ),
        SizedBox(height: space.xs.h),
        Text(
          l10n.talkSharePreviewHint,
          style: typo.caption.copyWith(color: colors.textSecondary),
        ),
        SizedBox(height: space.sm.h),
        for (final step in preview.steps) ...[
          TalkShareStepCard(
            routineId: routineId,
            step: step,
            card: cardByStepId[step.stepId],
            isBlurred: blurChoiceByStepId[step.stepId] == true,
          ),
          SizedBox(height: space.sm.h),
        ],
      ],
    );
  }
}
