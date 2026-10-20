import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/elum_multiline_text_field.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../../guardian/domain/routine_template.dart';
import '../../application/talk_detail_controller.dart';
import '../../domain/talk_post.dart';
import '../../domain/talk_screen_codes.dart';
import '../../domain/talk_text_limits.dart';
import 'talk_category_picker.dart';
import 'talk_sheet_frame.dart';

/// 내 글 고치기 시트: 한마디(300자) + 분류 > 저장. 저장하면 true
Future<bool> showTalkEditSheet(
  BuildContext context,
  TalkPostDetail post,
) async {
  final isSaved = await showElumSheet<bool>(
    context: context,
    builder: (_) => _TalkEditSheet(post: post),
  );
  return isSaved ?? false;
}

class _TalkEditSheet extends ConsumerStatefulWidget {
  const _TalkEditSheet({required this.post});

  final TalkPostDetail post;

  @override
  ConsumerState<_TalkEditSheet> createState() => _TalkEditSheetState();
}

class _TalkEditSheetState extends ConsumerState<_TalkEditSheet> {
  late final _noteController = TextEditingController(text: widget.post.note);
  late RoutineTemplateCategory? _category = widget.post.category;
  bool _isSaving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final category = _category;
    if (category == null || _isSaving) return;
    setState(() => _isSaving = true);
    final l10n = context.l10n;
    try {
      // 빈 문자열이면 서버가 한마디를 지운다
      await ref
          .read(talkDetailControllerProvider(widget.post.id).notifier)
          .updateNoteAndCategory(
            note: _noteController.text.trim(),
            category: category.serverValue,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      await showFailure(
        context,
        e,
        title: l10n.talkEditFailedTitle,
        fallback: l10n.talkFailedFallback,
        fallbackCode: TalkScreenCodes.managePost,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final space = context.space;

    return TalkSheetFrame(
      title: l10n.talkEditTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 한마디 (글자 수 카운터)
          Text(
            l10n.talkNoteLabel,
            style: context.typo.tileLabel.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: space.xs.h),
          ElumMultilineTextField(
            controller: _noteController,
            hintText: l10n.talkNoteGuide,
            maxLength: TalkTextLimits.maxNoteLength,
            minLines: 3,
            maxLines: 6,
            enabled: !_isSaving,
            onChanged: (_) => setState(() {}),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(top: space.xs.h),
              child: Text(
                '${_noteController.text.length}'
                '/${TalkTextLimits.maxNoteLength}',
                style: context.typo.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
          SizedBox(height: space.sm.h),
          // 분류
          Text(
            l10n.talkCategoryTitle,
            style: context.typo.tileLabel.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: space.xs.h),
          TalkCategoryPicker(
            selectedCategory: _category,
            isEnabled: !_isSaving,
            onSelected: (category) => setState(() => _category = category),
          ),
          SizedBox(height: space.xs.h),
          ElumButton(
            label: l10n.talkEditSave,
            loading: _isSaving,
            onPressed: _category == null ? null : _save,
          ),
        ],
      ),
    );
  }
}
