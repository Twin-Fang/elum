import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_bottom_sheet.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/kept_text.dart';
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

  /// 시안 위치: 시트 윗변에서 제목까지 · 저장 버튼 아래에서 화면 바닥까지
  /// (시안 시트 높이 445 = 화면 852 - 407 이 안전영역을 포함하므로 기기 안전영역을 더하지 않음)
  static const _topPadding = 40.0;
  static const _bottomPadding = 56.0;
  static const _sheetPadH = 16.0;

  /// 시트 윗변에서 손잡이 윗변까지 (시안 PNG 실측 12)
  static const _handleTop = 12.0;

  /// 제목·설명은 입력칸보다 8 안쪽에서 시작
  static const _textInset = 8.0;
  static const _titleToDescriptionGap = 24.0;
  static const _descriptionToFieldGap = 27.0;
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
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;

    return Padding(
      // 키보드가 올라오면 시트가 그 위로 올라옴
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ElumSheetSurface(
        handleTop: _handleTop,
        // 여백은 손잡이(시트 윗변 기준)를 밀지 않게 면 안쪽에서 준다.
        // 큰 글자에서 내용이 화면보다 길어지면 스크롤
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            _sheetPadH.w,
            _topPadding.h,
            _sheetPadH.w,
            _bottomPadding.h,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: _textInset.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.guardiansEditTitle,
                      style: typo.sheetTitle.copyWith(color: colors.sheetTitleText, letterSpacing: 0),
                    ),
                    SizedBox(height: _titleToDescriptionGap.h),
                    KeptText(
                      context.l10n.guardiansEditDescription,
                      style: typo.peopleEditDescription.copyWith(color: colors.peopleTextPrimary),
                    ),
                  ],
                ),
              ),
              SizedBox(height: _descriptionToFieldGap.h),
              _NameField(
                key: guardianEditNameFieldKey,
                controller: _nameController,
                hintText: context.l10n.guardiansEditNameHint,
                maxLength: _maxNameLength,
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
                labelStyle: typo.sheetActionLabel.copyWith(letterSpacing: 0),
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 이름 입력칸: 흰 바탕, 1px 테두리, 한 줄 전용
class _NameField extends StatelessWidget {
  const _NameField({super.key, required this.controller, required this.hintText, required this.maxLength});

  final TextEditingController controller;
  final String hintText;
  final int maxLength;

  /// 시안 글자 시작선은 칸 왼쪽에서 24. 입력 위젯이 4를 더 들여 쓰므로 그만큼 뺌
  static const _padStart = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    // 자간 0 고정 (테마 기본 0.25 상속 방지)
    final textStyle = context.typo.sheetFieldText.copyWith(
      color: colors.peopleTextPrimary,
      letterSpacing: 0,
    );

    OutlineInputBorder border(Color color, {double width = 1}) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(space.fieldRadius.r),
      borderSide: BorderSide(color: color, width: width),
    );

    return SizedBox(
      height: space.fieldH.h,
      child: TextField(
        controller: controller,
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        textAlignVertical: TextAlignVertical.center,
        // 높이는 부모(68)가, 세로 가운데는 정렬이 맡음
        expands: true,
        maxLines: null,
        minLines: null,
        // expands 가 줄바꿈 키보드로 추론되는 것을 막음
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.deny(RegExp(r'\n')),
          LengthLimitingTextInputFormatter(maxLength),
        ],
        style: textStyle,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: textStyle.copyWith(color: colors.peopleEditPlaceholder),
          filled: true,
          fillColor: colors.surface,
          contentPadding: EdgeInsets.symmetric(horizontal: _padStart.w),
          border: border(colors.border),
          enabledBorder: border(colors.border),
          focusedBorder: border(colors.goalSelectedBorder, width: space.selectedBorderWidth),
        ),
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
