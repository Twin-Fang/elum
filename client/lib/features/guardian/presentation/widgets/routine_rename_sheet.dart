import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/elum_text_field.dart';

/// 일과 이름 글자 수 상한. 서버 `PATCH /api/routines/{id}/title` 검증과 같은 값 (#804)
const routineTitleMaxLength = 30;

/// 이름 바꾸기 시트: 지금 이름이 채워진 입력칸 + 저장. 저장하면 새 이름(앞뒤 공백 제거)을 돌려준다
///
/// 비었거나 그대로면 저장을 막는다 — 서버에 보내 봐야 거절되거나 바뀌는 것이 없다.
Future<String?> showRoutineRenameSheet(
  BuildContext context, {
  required String currentTitle,
}) {
  return showElumSheet<String>(
    context: context,
    builder: (_) => _RoutineRenameSheet(currentTitle: currentTitle),
  );
}

class _RoutineRenameSheet extends StatefulWidget {
  const _RoutineRenameSheet({required this.currentTitle});

  final String currentTitle;

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

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      // 키보드에 가리지 않게 시트를 올린다
      padding: EdgeInsets.only(bottom: keyboard),
      child: ElumSheetSurface(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            space.md.w,
            space.lg.h,
            space.md.w,
            space.md.h + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.routineLibraryMenuRename,
                style: context.typo.sectionTitle.copyWith(
                  color: context.colors.textPrimary,
                ),
              ),
              SizedBox(height: space.md.h),
              ElumTextField(
                controller: _controller,
                hintText: context.l10n.routineLibraryRenameHint,
                maxLength: routineTitleMaxLength,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _save(),
              ),
              SizedBox(height: space.md.h),
              ElumButton(
                label: context.l10n.routineLibraryRenameSave,
                onPressed: _canSave ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
