import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_bottom_sheet.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_sheet_frame.dart';
import '../../../core/widgets/elum_sheet_text_field.dart';
import '../domain/guardian_member.dart';

/// 시트 안 위젯을 찾는 키 (테스트 · 문구와 무관하게 찾기 위함)
const guardianEditNameFieldKey = ValueKey('guardianEditNameField');
const guardianEditSaveButtonKey = ValueKey('guardianEditSaveButton');
ValueKey<String> guardianEditKindChipKey(GuardianKind kind) =>
    ValueKey('guardianEditKindChip-${kind.apiValue}');

/// 내 이름·구분 변경에서 돌려주는 값. 바뀐 항목만 값이 있다.
class GuardianEdit {
  const GuardianEdit({this.displayName, this.kind});

  final String? displayName;
  final GuardianKind? kind;

  bool get isEmpty => displayName == null && kind == null;
}

/// 이 이룸이 안에서 내가 불리는 이름과 구분을 바꾸는 시트.
///
/// 서버 `PATCH /api/profiles/{id}/guardians/me` 는 보낸 항목만 바꾼다. 그래서 처음 값과
/// 달라진 것만 돌려준다 (같은 값을 다시 보내 마지막에 바꾼 사람이 덮어쓰는 일 방지).
Future<GuardianEdit?> showGuardianEditSheet(BuildContext context, {required Guardian me}) {
  return showElumSheet<GuardianEdit>(
    context: context,
    barrierColor: context.colors.sheetScrim,
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
  /// 서버가 막는 길이 (넘기면 400 이라 입력에서 미리 막음)
  static const _maxNameLength = 20;

  /// 시안 1532:6877 실측: 입력칸 > 구분 칩 24 · 칩 > 저장 40 (제목 · 설명 · 머리 > 본문은 [ElumSheetFrame])
  static const _fieldToChipsGap = 24.0;
  static const _chipsToButtonGap = 40.0;

  late final _nameController = TextEditingController(text: widget.me.displayName ?? '');
  late GuardianKind _selectedKind = widget.me.kind;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final nameBefore = widget.me.displayName?.trim() ?? '';
    Navigator.of(context).pop(
      GuardianEdit(
        displayName: name == nameBefore ? null : name,
        kind: _selectedKind == widget.me.kind ? null : _selectedKind,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    // 공통 시트 틀: 제목 > 설명 > 입력칸 · 구분 칩 · 저장 (키보드 · 큰 글자 스크롤 포함)
    return ElumSheetFrame(
      title: context.l10n.guardiansEditTitle,
      description: context.l10n.guardiansEditDescription,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElumSheetTextField(
            key: guardianEditNameFieldKey,
            controller: _nameController,
            hintText: context.l10n.guardiansEditNameHint,
            maxLength: _maxNameLength,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
          ),
          SizedBox(height: _fieldToChipsGap.h),
          // 구분은 표시용 (권한 차이 없음). 둘 중 하나라 칩 둘로 둠
          Row(
            children: [
              for (final (index, kind) in GuardianKind.values.indexed) ...[
                if (index > 0) SizedBox(width: space.sm.w),
                _KindChip(
                  key: guardianEditKindChipKey(kind),
                  kind: kind,
                  isSelected: _selectedKind == kind,
                  onTap: () => setState(() => _selectedKind = kind),
                ),
              ],
            ],
          ),
          SizedBox(height: _chipsToButtonGap.h),
          ElumButton(
            key: guardianEditSaveButtonKey,
            label: context.l10n.guardiansEditSave,
            labelStyle: context.typo.sheetActionLabel.copyWith(letterSpacing: 0),
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

/// 구분 칩 (보호자 · 선생님). 고르면 그 구분의 칩 색으로 바뀜
class _KindChip extends StatelessWidget {
  const _KindChip({super.key, required this.kind, required this.isSelected, required this.onTap});

  final GuardianKind kind;
  final bool isSelected;
  final VoidCallback onTap;

  static const _minHeight = 42.0;
  static const _padH = 24.0;
  static const _borderWidth = 1.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isCaregiver = kind == GuardianKind.caregiver;
    final selectedBackground = isCaregiver ? colors.peopleCaregiverChipBg : colors.peopleGuardianChipBg;
    final selectedBorder = isCaregiver ? colors.peopleCaregiverChipBorder : colors.peopleGuardianChipBorder;
    final selectedText = isCaregiver ? colors.peopleCaregiverChipText : colors.peopleGuardianChipText;

    return Semantics(
      button: true,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      child: AppPressable(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: _minHeight.h),
          // 테두리는 칩 크기 안쪽이라 고른 칩만 두께만큼 여백을 덜어 두 칩의 크기를 맞춤
          padding: EdgeInsets.symmetric(
            horizontal: (isSelected ? _padH - _borderWidth : _padH).w,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? selectedBackground : colors.surface,
            borderRadius: BorderRadius.circular(_minHeight.r),
            border: isSelected ? Border.all(color: selectedBorder, width: _borderWidth) : null,
          ),
          child: Text(
            kind.label,
            maxLines: 1,
            style: context.typo.peopleEditChipLabel.copyWith(
              color: isSelected ? selectedText : colors.peopleEditChipIdleText,
            ),
          ),
        ),
      ),
    );
  }
}
