import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/theme_context_ext.dart';

/// 여러 줄 입력창. `ElumTextField` 는 한 줄 전용이라 같은 모양(흰 배경·r20·1px 테두리)으로 따로 만든다.
class ElumMultilineTextField extends StatelessWidget {
  const ElumMultilineTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.maxLength,
    this.minLines = defaultMinLines,
    this.maxLines,
    this.enabled = true,
    this.onChanged,
    this.textStyle,
  });

  final TextEditingController controller;
  final String hintText;
  final int maxLength;

  /// 처음 보이는 줄 수 (의견 보내기 8줄, 댓글 입력줄은 1줄)
  final int minLines;

  /// 늘어날 수 있는 최대 줄 수. null 이면 제한 없음
  final int? maxLines;

  /// 전송 중에는 입력을 잠근다.
  final bool enabled;
  final ValueChanged<String>? onChanged;

  /// 입력 · 안내 글자. null 이면 input 글꼴(기본). 화면 글꼴에 맞출 때만 넘긴다 (이야기는 Pretendard)
  final TextStyle? textStyle;

  static const defaultMinLines = 8;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final radius = BorderRadius.circular(space.fieldRadius.r);
    final textStyle = this.textStyle ?? context.typo.input;
    final border = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colors.border),
    );

    return TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
      style: textStyle.copyWith(color: colors.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: textStyle.copyWith(color: colors.textPlaceholder),
        filled: true,
        fillColor: colors.surface,
        contentPadding: EdgeInsets.all(space.md.w),
        border: border,
        enabledBorder: border,
        disabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            color: colors.goalSelectedBorder,
            width: space.selectedBorderWidth,
          ),
        ),
      ),
    );
  }
}
