import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_bottom_sheet.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_text_field.dart';
import '../domain/guardian_member.dart';

/// 내 이름·구분 고치기에서 돌려주는 값. 바뀐 항목만 값이 있다.
class GuardianEdit {
  const GuardianEdit({this.displayName, this.kind});

  final String? displayName;
  final GuardianKind? kind;

  bool get isEmpty => displayName == null && kind == null;
}

/// 이 이룸이 안에서 **내가 불리는 이름**과 구분을 고치는 시트.
///
/// > ⚠️ **임시 시안이다.** 시안이 없어 이름 입력 필드(`ElumTextField`)와 버튼을 그대로 썼다.
///
/// 서버 `PATCH /api/profiles/{id}/guardians/me` 는 **보낸 항목만 바꾼다.** 그래서 이 시트는
/// 처음 값과 달라진 것만 돌려준다 — 같은 값을 다시 보내 마지막에 바꾼 사람이 덮어쓰는 일이
/// 없다. 실명을 적을 필요가 없다고 먼저 말한다 (원칙 1 · 개인정보 최소 수집).
Future<GuardianEdit?> showGuardianEditSheet(
  BuildContext context, {
  required Guardian me,
}) {
  return showElumSheet<GuardianEdit>(
    context: context,
    builder: (_) => _GuardianEditSheet(me: me),
  );
}

class _GuardianEditSheet extends StatefulWidget {
  const _GuardianEditSheet({required this.me});

  final Guardian me;

  @override
  State<_GuardianEditSheet> createState() => _GuardianEditSheetState();
}

class _GuardianEditSheetState extends State<_GuardianEditSheet> {
  /// 서버가 막는 길이 — 넘기면 400 이라 입력에서 미리 막는다.
  static const _maxName = 20;

  late final _controller = TextEditingController(text: widget.me.displayName ?? '');
  late GuardianKind _kind = widget.me.kind;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    final before = widget.me.displayName?.trim() ?? '';
    Navigator.of(context).pop(
      GuardianEdit(
        displayName: name == before ? null : name,
        kind: _kind == widget.me.kind ? null : _kind,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final typo = context.typo;

    return Padding(
      // 키보드가 올라오면 시트가 그 위로 올라온다.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ElumSheetSurface(
        showHandle: false,
        padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 32.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.guardiansEditTitle,
              style: typo.sectionTitle.copyWith(color: colors.textPrimary),
            ),
            SizedBox(height: space.xs),
            Text(
              context.l10n.guardiansEditDescription,
              style: typo.body.copyWith(color: colors.textSecondary),
            ),
            SizedBox(height: space.lg),
            ElumTextField(
              controller: _controller,
              hintText: context.l10n.guardiansEditNameHint,
              maxLength: _maxName,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
            ),
            SizedBox(height: space.md),
            // 구분은 표시용이다 — 권한 차이가 없다. 둘 중 하나라 칩 둘로 둔다.
            Row(
              children: [
                for (final kind in GuardianKind.values) ...[
                  _KindChip(
                    label: kind.label,
                    selected: _kind == kind,
                    onTap: () => setState(() => _kind = kind),
                  ),
                  SizedBox(width: space.sm),
                ],
              ],
            ),
            SizedBox(height: space.lg),
            ElumButton(label: context.l10n.guardiansEditSave, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppPressable(
      onTap: onTap,
      // 칩 높이 48 — 손끝 최소 영역이다.
      child: Container(
        height: 48.h,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.goalSelectedFill : colors.surface,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: selected ? colors.goalSelectedBorder : colors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: context.typo.body.copyWith(color: colors.textPrimary),
        ),
      ),
    );
  }
}
