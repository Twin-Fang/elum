import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/elum_text_field.dart';

/// 카드 제목·설명 수정 바텀시트 (이슈 #77).
///
/// Figma에 수정 화면 시안이 없다 — 디자이너가 키보드 가림 문제로 확정하지 못해
/// 바텀시트로 정했다. `isScrollControlled` + `viewInsets.bottom` 패딩으로
/// **시트가 키보드 위에 붙어** 입력칸이 가려지지 않는다.
///
/// 시트는 값만 돌려준다. 저장(서버 반영)은 호출한 화면의 몫이다 —
/// 시트가 notifier까지 알면 아이 화면 재사용이 막힌다.
class CardEditSheet extends StatefulWidget {
  const CardEditSheet({
    super.key,
    required this.initialTitle,
    required this.initialDescription,
  });

  final String initialTitle;
  final String initialDescription;

  /// 수정 결과. 저장을 눌러야만 값이 돌아오고, 밖을 탭해 닫으면 null이다.
  static Future<({String title, String description})?> show(
    BuildContext context, {
    required String title,
    required String description,
  }) {
    return showModalBottomSheet<({String title, String description})>(
      context: context,
      // 키보드 높이만큼 시트가 올라와야 입력칸이 보인다
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CardEditSheet(
        initialTitle: title,
        initialDescription: description,
      ),
    );
  }

  @override
  State<CardEditSheet> createState() => _CardEditSheetState();
}

class _CardEditSheetState extends State<CardEditSheet> {
  late final _titleController = TextEditingController(text: widget.initialTitle);
  late final _descriptionController =
      TextEditingController(text: widget.initialDescription);

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// 제목·설명 둘 다 있어야 저장할 수 있다.
  /// 빈 카드가 저장되면 아동 화면에 내용 없는 카드가 나간다.
  bool get _canSave =>
      _titleController.text.trim().isNotEmpty &&
      _descriptionController.text.trim().isNotEmpty;

  void _save() {
    Navigator.of(context).pop((
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    // 키보드가 차지한 높이. 이만큼 밀어 올려야 입력칸이 가려지지 않는다.
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(space.cardRadius.r),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          space.screenH,
          space.lg,
          space.screenH,
          space.lg,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '카드 수정하기',
                style: context.typo.reviewTitle
                    .copyWith(color: colors.textPrimary),
              ),
              SizedBox(height: space.lg),
              Text(
                '제목',
                style: context.typo.promptBody
                    .copyWith(color: colors.promptMuted),
              ),
              SizedBox(height: space.xs),
              ElumTextField(
                hintText: '카드 제목을 적어주세요',
                controller: _titleController,
                explicitTextAlign: TextAlign.left,
                onChanged: (_) => setState(() {}),
              ),
              SizedBox(height: space.md),
              Text(
                '설명',
                style: context.typo.promptBody
                    .copyWith(color: colors.promptMuted),
              ),
              SizedBox(height: space.xs),
              _DescriptionField(
                controller: _descriptionController,
                onChanged: (_) => setState(() {}),
              ),
              SizedBox(height: space.lg),
              ElumButton(
                label: '저장하기',
                onPressed: _canSave ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 설명 입력칸. [ElumTextField]는 한 줄 전용(높이 68 고정)이라
/// 두 줄 설명이 잘린다 — 여러 줄 입력만 따로 만든다.
class _DescriptionField extends StatelessWidget {
  const _DescriptionField({required this.controller, this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      minLines: 2,
      maxLines: 4,
      style: context.typo.input.copyWith(color: colors.textPrimary),
      decoration: InputDecoration(
        hintText: '카드 설명을 적어주세요',
        hintStyle: context.typo.input.copyWith(color: colors.textPlaceholder),
        filled: true,
        fillColor: colors.surface,
        contentPadding: EdgeInsets.all(space.md.w),
        border: _border(colors.border, space.fieldRadius.r),
        enabledBorder: _border(colors.border, space.fieldRadius.r),
        focusedBorder: _border(
          colors.goalSelectedBorder,
          space.fieldRadius.r,
          width: space.selectedBorderWidth,
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color, double radius, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
