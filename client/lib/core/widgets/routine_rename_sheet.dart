import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/l10n_context.dart';
import 'elum_bottom_sheet.dart';
import 'elum_button.dart';
import 'elum_sheet_frame.dart';
import 'elum_sheet_text_field.dart';

/// 일과 이름 글자 수 상한. 서버 `PATCH /api/routines/{id}/title` 검증과 같은 값 (#804)
const routineTitleMaxLength = 30;

/// 이름 바꾸기 시트 (시안 1759:9649 이름 시트 결): 지금 이름이 채워진 입력칸 + 저장. 저장하면 새 이름(앞뒤 공백 제거)을 돌려준다
///
/// 비었거나 그대로면 저장을 막는다 — 서버에 보내 봐야 거절되거나 바뀌는 것이 없다.
/// 묶음 이름도 같은 시트를 쓴다 (#807): [maxLength] · [hintText] 만 다르다.
Future<String?> showRoutineRenameSheet(
  BuildContext context, {
  required String currentTitle,
  int maxLength = routineTitleMaxLength,
  String? hintText,
}) {
  return showElumSheet<String>(
    context: context,
    builder: (_) => _RoutineRenameSheet(
      currentTitle: currentTitle,
      maxLength: maxLength,
      hintText: hintText,
    ),
  );
}

class _RoutineRenameSheet extends StatefulWidget {
  const _RoutineRenameSheet({
    required this.currentTitle,
    required this.maxLength,
    required this.hintText,
  });

  final String currentTitle;
  final int maxLength;

  /// 비우면 일과 이름 안내 글
  final String? hintText;

  @override
  State<_RoutineRenameSheet> createState() => _RoutineRenameSheetState();
}

class _RoutineRenameSheetState extends State<_RoutineRenameSheet> {
  late final _controller = TextEditingController(text: widget.currentTitle);

  @override
  void initState() {
    super.initState();
    // 지금 이름을 통째로 골라 두어 바로 새로 쓸 수 있게
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.currentTitle.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _newTitle => _controller.text.trim();

  bool get _canSave =>
      _newTitle.isNotEmpty && _newTitle != widget.currentTitle.trim();

  void _save() {
    if (!_canSave) return;
    Navigator.of(context).pop(_newTitle);
  }

  /// 입력칸 > 저장 버튼 (시안 1759:9649: 40)
  static const _fieldToButton = 40.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ElumSheetFrame(
      title: l10n.routineLibraryMenuRename,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElumSheetTextField(
            controller: _controller,
            hintText: widget.hintText ?? l10n.routineLibraryRenameHint,
            maxLength: widget.maxLength,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
          ),
          SizedBox(height: _fieldToButton.h),
          ElumButton(
            label: l10n.routineLibraryRenameSave,
            onPressed: _canSave ? _save : null,
          ),
        ],
      ),
    );
  }
}
