import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';

/// 여러 줄 입력창. `ElumTextField` 는 한 줄 전용이라 같은 모양(흰 배경·r20·1px 테두리)으로 따로 만든다.
class FeedbackTextBox extends StatelessWidget {
  const FeedbackTextBox({
    super.key,
    required this.controller,
    required this.hintText,
    required this.maxLength,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final int maxLength;

  /// 전송 중에는 입력을 잠근다.
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final radius = BorderRadius.circular(space.fieldRadius.r);
    final border = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colors.border),
    );

    return TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      minLines: 8,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
      style: context.typo.input.copyWith(color: colors.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: context.typo.input.copyWith(color: colors.textPlaceholder),
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
