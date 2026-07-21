import 'package:flutter/material.dart';

import '../theme/theme_context_ext.dart';

/// 입력 필드. Figma 기준 344×68 / radius 20 / 흰 배경 + 1px 테두리.
///
/// placeholder는 중앙 정렬이다 (Figma `이름을 입력해주세요` 기준).
class ElumTextField extends StatelessWidget {
  const ElumTextField({
    super.key,
    required this.hintText,
    this.controller,
    this.onChanged,
    this.textAlign = TextAlign.center,
  });

  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return SizedBox(
      height: space.fieldH,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textAlign: textAlign,
        textAlignVertical: TextAlignVertical.center,
        style: context.typo.input.copyWith(color: colors.textPrimary),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: context.typo.input.copyWith(color: colors.textPlaceholder),
          filled: true,
          fillColor: colors.surface,
          contentPadding: EdgeInsets.symmetric(horizontal: space.md),
          border: _border(colors.border, space.fieldRadius),
          enabledBorder: _border(colors.border, space.fieldRadius),
          focusedBorder: _border(colors.selectedBorder, space.fieldRadius, width: 2),
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
