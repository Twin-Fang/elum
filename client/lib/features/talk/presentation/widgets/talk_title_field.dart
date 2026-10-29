import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_text_field.dart';
import '../../../../core/widgets/routine_rename_sheet.dart';

/// 올리기 `일과 제목` 입력칸 (시안 1931:7181): 한 줄 · 높이 58 · 안쪽 20 · 600/18
/// 고친 제목은 올리기 전에 일과관리 일과 이름으로 저장된다
class TalkTitleField extends StatelessWidget {
  const TalkTitleField({
    super.key,
    required this.controller,
    required this.isEnabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool isEnabled;
  final ValueChanged<String> onChanged;

  /// 칸 높이 · 좌우 안쪽 (시안 58 · 20)
  static const _fieldHeight = 58.0;
  static const _contentInset = 20.0;

  @override
  Widget build(BuildContext context) {
    return ElumTextField(
      controller: controller,
      hintText: context.l10n.talkShareTitleHint,
      maxLength: routineTitleMaxLength,
      inputStyle: context.typo.talkShareTitleInput,
      isEnabled: isEnabled,
      fieldHeight: _fieldHeight,
      horizontalInset: _contentInset,
      onChanged: onChanged,
    );
  }
}
