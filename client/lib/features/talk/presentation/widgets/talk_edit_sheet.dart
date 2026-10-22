import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/elum_sheet_frame.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../../guardian/domain/routine_template.dart';
import '../../application/talk_detail_controller.dart';
import '../../domain/talk_post.dart';
import '../../domain/talk_screen_codes.dart';
import 'talk_category_picker.dart';
import 'talk_form_section.dart';
import 'talk_note_field.dart';

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

  /// 구역 사이 · 마지막 구역 > 버튼 (구역 사이 40: 올리기 1870:9398 · design-language 구역 간격)
  static const _sectionGap = 40.0;
  static const _sectionsToButton = 32.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ElumSheetFrame(
      title: l10n.talkEditTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TalkFormSection(
            label: l10n.talkNoteLabel,
            child: TalkNoteField(
              controller: _noteController,
              isEnabled: !_isSaving,
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(height: _sectionGap.h),
          TalkFormSection(
            label: l10n.talkCategoryTitle,
            child: TalkCategoryPicker(
              selectedCategory: _category,
              isEnabled: !_isSaving,
              onSelected: (category) => setState(() => _category = category),
            ),
          ),
          SizedBox(height: _sectionsToButton.h),
          ElumButton(
            label: l10n.talkEditSave,
            labelStyle: context.typo.sheetActionLabel,
            loading: _isSaving,
            onPressed: _category == null ? null : _save,
          ),
        ],
      ),
    );
  }
}
