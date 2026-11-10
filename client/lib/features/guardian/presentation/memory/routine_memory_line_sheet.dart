import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/elum_sheet_frame.dart';
import '../../../../core/widgets/elum_sheet_text_field.dart';
import '../../../../core/widgets/elum_text_link.dart';
import '../../domain/routine_memory.dart';

/// 메모 줄 시트 결과: 저장(새 글) 또는 지우기
sealed class RoutineMemoryLineSheetResult {
  const RoutineMemoryLineSheetResult();
}

class RoutineMemoryLineSaved extends RoutineMemoryLineSheetResult {
  const RoutineMemoryLineSaved(this.text);

  final String text;
}

class RoutineMemoryLineDeleted extends RoutineMemoryLineSheetResult {
  const RoutineMemoryLineDeleted();
}

/// 메모 한 줄 더하기·고치기 시트: 입력칸(60자) > 저장, 고치기면 아래에 `이 줄 지우기`
/// [currentText] 가 null 이면 더하기
Future<RoutineMemoryLineSheetResult?> showRoutineMemoryLineSheet(
  BuildContext context, {
  String? currentText,
}) {
  return showElumSheet<RoutineMemoryLineSheetResult>(
    context: context,
    builder: (_) => _RoutineMemoryLineSheet(currentText: currentText),
  );
}

class _RoutineMemoryLineSheet extends StatefulWidget {
  const _RoutineMemoryLineSheet({required this.currentText});

  final String? currentText;

  @override
  State<_RoutineMemoryLineSheet> createState() => _RoutineMemoryLineSheetState();
}

class _RoutineMemoryLineSheetState extends State<_RoutineMemoryLineSheet> {
  late final _controller = TextEditingController(text: widget.currentText ?? '');

  /// 입력칸 > 저장 버튼 (이름 바꾸기 시트와 같은 40) · 저장 > 지우기 글자 버튼
  static const _fieldToButton = 40.0;
  static const _buttonToLink = 16.0;
  static const _fieldMaxLines = 2;

  bool get _isEditing => widget.currentText != null;

  String get _newText => _controller.text.trim();

  bool get _canSave => _newText.isNotEmpty && _newText != widget.currentText?.trim();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!_canSave) return;
    Navigator.of(context).pop(RoutineMemoryLineSaved(_newText));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ElumSheetFrame(
      title: _isEditing ? l10n.routineMemoryEditSheetTitle : l10n.routineMemoryAddSheetTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElumSheetTextField(
            controller: _controller,
            hintText: l10n.routineMemoryLineHint,
            maxLength: RoutineMemory.maxTextLength,
            maxLines: _fieldMaxLines,
            isAutofocused: true,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
          ),
          SizedBox(height: _fieldToButton.h),
          ElumButton(label: l10n.routineMemorySave, onPressed: _canSave ? _save : null),
          if (_isEditing) ...[
            SizedBox(height: _buttonToLink.h),
            ElumTextLink(
              label: l10n.routineMemoryDeleteLine,
              onTap: () => Navigator.of(context).pop(const RoutineMemoryLineDeleted()),
            ),
          ],
        ],
      ),
    );
  }
}
