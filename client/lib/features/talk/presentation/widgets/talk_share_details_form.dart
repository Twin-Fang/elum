import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../shared/models/action_card.dart';
import '../../../guardian/domain/routine_template.dart';
import '../../domain/talk_preview.dart';
import 'talk_category_picker.dart';
import 'talk_form_section.dart';
import 'talk_note_field.dart';
import 'talk_share_step_card.dart';
import 'talk_title_field.dart';

/// 올리기 마지막 단계 (시안 1870:9398): 일과 제목(고치면 일과 이름도 바뀜) > 내용(300자) > 분류 > 이렇게 보여요(상세와 같은 카드 격자)
class TalkShareDetailsForm extends StatelessWidget {
  const TalkShareDetailsForm({
    super.key,
    required this.routineId,
    required this.preview,
    required this.cardByStepId,
    required this.blurChoiceByStepId,
    required this.titleController,
    required this.noteController,
    required this.category,
    required this.onTitleChanged,
    required this.onNoteChanged,
    required this.onCategorySelected,
    this.isEnabled = true,
  });

  final String routineId;
  final TalkPreview preview;
  final Map<String, ActionCard> cardByStepId;

  /// 흐리게를 고른 카드는 미리보기에서도 흐리게 보인다
  final Map<String, bool?> blurChoiceByStepId;
  final TextEditingController titleController;
  final TextEditingController noteController;
  final RoutineTemplateCategory? category;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onNoteChanged;
  final ValueChanged<RoutineTemplateCategory> onCategorySelected;

  /// false 면 입력을 잠근다 (올리는 중)
  final bool isEnabled;

  /// 머리 줄 끝(y119) > `일과 제목` 이름 (시안 y139)
  static const topSpacing = 20.0;

  /// 구역 사이 (시안 1870:9398: 제목 칸 끝 222 > 내용 262, 분류 칩 끝 529 > 이렇게 보여요 569)
  static const _sectionGap = 40.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sectionLabelStyle = context.typo.talkShareSectionLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TalkFormSection(
          label: l10n.talkShareTitleLabel,
          labelStyle: sectionLabelStyle,
          labelToChildSpacing: TalkFormSection.labelToFieldSpacing,
          child: TalkTitleField(
            controller: titleController,
            isEnabled: isEnabled,
            onChanged: onTitleChanged,
          ),
        ),
        SizedBox(height: _sectionGap.h),
        TalkFormSection(
          label: l10n.talkNoteLabel,
          labelStyle: sectionLabelStyle,
          labelToChildSpacing: TalkFormSection.labelToFieldSpacing,
          child: TalkNoteField(
            controller: noteController,
            isEnabled: isEnabled,
            onChanged: onNoteChanged,
          ),
        ),
        SizedBox(height: _sectionGap.h),
        TalkFormSection(
          label: l10n.talkCategoryTitle,
          labelStyle: sectionLabelStyle,
          labelToChildSpacing: TalkFormSection.labelToChoicesSpacing,
          child: TalkCategoryPicker(
            selectedCategory: category,
            isEnabled: isEnabled,
            onSelected: onCategorySelected,
          ),
        ),
        SizedBox(height: _sectionGap.h),
        // 올라간 뒤 상세와 같은 카드 격자
        TalkFormSection(
          label: l10n.talkSharePreviewTitle,
          labelStyle: sectionLabelStyle,
          labelToChildSpacing: TalkFormSection.labelToChoicesSpacing,
          child: TalkShareCardGrid(
            itemCount: preview.steps.length,
            itemBuilder: (context, index, cellWidth) {
              final step = preview.steps[index];
              return TalkShareStepCard(
                routineId: routineId,
                step: step,
                card: cardByStepId[step.stepId],
                index: index,
                width: cellWidth,
                isBlurred: blurChoiceByStepId[step.stepId] == true,
              );
            },
          ),
        ),
      ],
    );
  }
}
