import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_button.dart';
import 'routine_flow_scaffold.dart' show dismissKeyboard;

/// 시트가 카드를 고치는지, 새로 넣는지.
enum CardSheetMode { edit, add }

/// 카드 제목·설명 시트 — 수정과 추가가 함께 쓴다 (#444).
///
/// 시안 `1197:5923`(수정) · `1197:6161`(수정 + 키보드) · `1197:6044`(추가).
/// 이슈 #77 때는 시안이 없어 바텀시트로 정했고, 지금은 시안 좌표를 그대로 따른다.
///
/// **키보드가 올라오면 시트가 위로 커진다(y=82, 높이 770).** 입력칸을 키보드 위로
/// 밀어 올리는 것이 아니라 시트 자체가 화면 위까지 자라고, 버튼은 시트 바닥(키보드
/// 뒤)에 남는다. 입력칸은 키보드 위(y≤326)에 그대로 있어 가려지지 않는다.
///
/// 시트는 값만 돌려준다. 서버 반영은 호출한 화면의 몫이다.
class CardEditSheet extends StatefulWidget {
  const CardEditSheet({
    super.key,
    required this.mode,
    this.initialTitle = '',
    this.initialDescription = '',
    this.onSubmit,
  });

  final CardSheetMode mode;

  /// 값을 받아 서버에 넣는다. true 면 시트가 닫히고, false 면 **열린 채 입력을 남긴다.**
  ///
  /// null 이면 값만 돌려주고 닫는다(수정 — 실패는 호출한 화면이 닫힌 뒤 알린다).
  /// 추가는 새 카드의 id 를 서버가 줘야 해서, 실패했는데 시트가 닫히면 보호자가 쓴
  /// 글이 사라진다.
  final Future<bool> Function(String title, String description)? onSubmit;
  final String initialTitle;
  final String initialDescription;

  /// 시안 좌표 (393×852 기준).
  ///
  /// 시트 높이는 수정 450 · 추가 488 — 추가는 제목 위에 40 이 더 있다. 시안 추가 시트에
  /// 그 자리에 `설명` 글자가 하나 더 있는데 복사하다 남은 잔재라 그리지 않는다(#444).
  static const _heightEdit = 450.0;
  static const _heightAdd = 488.0;

  /// 키보드가 올라오면 시트 윗변이 이 자리(y=82)까지 올라간다.
  static const _keyboardTop = 82.0;

  /// 수정 시트에서의 위치. 추가 시트는 [_addOffset] 만큼 아래다.
  static const _titleY = 40.0;
  static const _titleLabelY = 84.0;
  static const _titleFieldY = 109.0;
  static const _descLabelY = 193.0;
  static const _descFieldY = 218.0;
  static const _addOffset = 40.0;

  /// 수정 결과. 완료를 눌러야만 값이 돌아오고, 밖을 탭해 닫으면 null이다.
  static Future<({String title, String description})?> show(
    BuildContext context, {
    required String title,
    required String description,
  }) {
    return _open(
      context,
      CardEditSheet(
        mode: CardSheetMode.edit,
        initialTitle: title,
        initialDescription: description,
      ),
    );
  }

  /// 새 카드. 결과는 [show] 와 같다.
  static Future<({String title, String description})?> showAdd(
    BuildContext context, {
    required Future<bool> Function(String title, String description) onSubmit,
  }) {
    return _open(
      context,
      CardEditSheet(mode: CardSheetMode.add, onSubmit: onSubmit),
    );
  }

  static Future<({String title, String description})?> _open(
    BuildContext context,
    CardEditSheet sheet,
  ) {
    return showModalBottomSheet<({String title, String description})>(
      context: context,
      // 시트가 키보드 때문에 화면 위까지 자란다
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: context.colors.sheetScrim,
      builder: (_) => sheet,
    );
  }

  @override
  State<CardEditSheet> createState() => _CardEditSheetState();
}

class _CardEditSheetState extends State<CardEditSheet> {
  late final _titleController = TextEditingController(
    text: widget.initialTitle,
  );
  late final _descriptionController = TextEditingController(
    text: widget.initialDescription,
  );

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _isAdd => widget.mode == CardSheetMode.add;

  /// 제목·설명 둘 다 있어야 저장할 수 있다.
  /// 빈 카드가 저장되면 이룸이 화면에 내용 없는 카드가 나간다.
  bool get _canSave =>
      _titleController.text.trim().isNotEmpty &&
      _descriptionController.text.trim().isNotEmpty;

  /// 서버에 넣는 동안 다시 눌러도 두 번 가지 않게 막는다.
  var _busy = false;

  Future<void> _save() async {
    if (_busy) return;
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final submit = widget.onSubmit;

    if (submit != null) {
      setState(() => _busy = true);
      final ok = await submit(title, description);
      if (!mounted) return;
      setState(() => _busy = false);
      // 실패하면 열어 둔다 — 쓴 글이 남아 있어야 다시 누를 수 있다
      if (!ok) return;
    }
    if (!mounted) return;
    Navigator.of(context).pop((title: title, description: description));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    // 추가 시트는 제목 위에 40 이 더 있다
    final off = _isAdd ? CardEditSheet._addOffset : 0.0;

    final height = keyboardOpen
        ? (852 - CardEditSheet._keyboardTop).h
        : (_isAdd ? CardEditSheet._heightAdd : CardEditSheet._heightEdit).h;

    return GestureDetector(
      // 빈 곳을 누르면 키보드가 내려간다 — 버튼이 키보드 뒤에 있어 내려야 누를 수 있다
      behavior: HitTestBehavior.opaque,
      onTap: dismissKeyboard,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: Curves.easeOut,
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: Stack(
          children: [
            // 손잡이 — 시안은 굵기 4 선의 **가운데**가 y=16 이라 윗변은 14 다 (x=177, 폭 40)
            Positioned(
              top: 14.h,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: colors.sheetHandle,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24.w,
              top: CardEditSheet._titleY.h,
              child: Text(
                _isAdd ? '새로운 카드 추가' : '카드 수정',
                style: typo.sheetHeading.copyWith(color: colors.textPrimary),
              ),
            ),
            Positioned(
              left: 24.w,
              top: (CardEditSheet._titleLabelY + off).h,
              child: Text(
                '제목',
                style: typo.sheetFieldLabel.copyWith(
                  color: colors.sheetFieldLabelText,
                ),
              ),
            ),
            Positioned(
              left: 16.w,
              right: 16.w,
              top: (CardEditSheet._titleFieldY + off).h,
              child: _SheetField(
                controller: _titleController,
                hintText: '카드 제목을 적어주세요',
                maxLines: 1,
                onChanged: (_) => setState(() {}),
              ),
            ),
            Positioned(
              left: 24.w,
              top: (CardEditSheet._descLabelY + off).h,
              child: Text(
                '설명',
                style: typo.sheetFieldLabel.copyWith(
                  color: colors.sheetFieldLabelText,
                ),
              ),
            ),
            Positioned(
              left: 16.w,
              right: 16.w,
              top: (CardEditSheet._descFieldY + off).h,
              child: _SheetField(
                controller: _descriptionController,
                hintText: '카드 설명을 적어주세요',
                // 시안 칸은 한 줄 높이(68)다. 긴 설명은 두 줄까지 칸 안에서 보인다
                maxLines: 2,
                onChanged: (_) => setState(() {}),
              ),
            ),
            // 버튼은 시트 바닥에서 56 위 (450 = 328 + 66 + 56)
            Positioned(
              left: space.buttonMarginH.w,
              right: space.buttonMarginH.w,
              bottom: 56.h,
              child: ElumButton(
                label: _isAdd ? '추가하기' : '완료',
                onPressed: _canSave && !_busy ? _save : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 시트 입력칸 — 361×68 / 흰 배경 / 1px 테두리 / 라운드 20 (시안 1197:6040).
///
/// [ElumTextField]를 쓰지 않는다. 그쪽은 글자가 Tmoney 20 이고 한 줄 전용인데,
/// 시안 시트의 글자는 16/w400(줄 1.2)이고 설명은 두 줄까지 들어가야 한다.
class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    required this.hintText,
    required this.maxLines,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.typo.sheetFieldText;

    return Container(
      height: context.space.fieldH.h,
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: colors.border),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        minLines: 1,
        maxLines: maxLines,
        // 시안은 한 줄 칸이라 줄바꿈 키가 아니라 완료 키다
        textInputAction: TextInputAction.done,
        keyboardType: TextInputType.text,
        // 붙여넣기로 들어오는 개행까지 막는다 — 설명은 소리로 읽히는 한 문장이다
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\n'))],
        style: style.copyWith(color: colors.textPrimary),
        decoration: InputDecoration.collapsed(
          hintText: hintText,
          hintStyle: style.copyWith(color: colors.textPlaceholder),
        ),
      ),
    );
  }
}
