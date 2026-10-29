import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/theme_context_ext.dart';

/// 시트 안 입력칸 (시안 1197:5923 · 1877:9740): 회색 라벨 > 흰 칸 68 r20 · 1px #EFEFEF · Pretendard 16
/// 안내는 칸 안 placeholder 로만 둔다. 온보딩 큰 입력칸(Tmoney 20)은 `ElumTextField`
class ElumSheetTextField extends StatelessWidget {
  const ElumSheetTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.label,
    this.maxLines = 1,
    this.maxLength,
    this.isAutofocused = false,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;

  /// 칸 위 회색 라벨. null 이면 자리도 없다
  final String? label;
  final int maxLines;
  final int? maxLength;
  final bool isAutofocused;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// 시안 실측: 라벨 > 칸 9 · 글 안쪽 24 · 라벨이 칸보다 8 안쪽(x=24)
  static const _labelToField = 9.0;
  static const _textInsetH = 24.0;
  static const _labelInset = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    final style = typo.sheetFieldText;
    final label = this.label;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _labelInset.w),
            child: Text(
              label,
              style: typo.sheetFieldLabel.copyWith(
                color: colors.sheetFieldLabelText,
              ),
            ),
          ),
          SizedBox(height: _labelToField.h),
        ],
        Container(
          constraints: BoxConstraints(minHeight: space.fieldH.h),
          padding: EdgeInsets.symmetric(horizontal: _textInsetH.w),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(space.fieldRadius.r),
            border: Border.all(color: colors.border),
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            autofocus: isAutofocused,
            minLines: 1,
            maxLines: maxLines,
            textInputAction: maxLines == 1
                ? TextInputAction.done
                : TextInputAction.newline,
            inputFormatters: [
              if (maxLength != null)
                LengthLimitingTextInputFormatter(maxLength),
            ],
            style: style.copyWith(color: colors.textPrimary),
            decoration: InputDecoration.collapsed(
              hintText: hintText,
              hintStyle: style.copyWith(color: colors.textPlaceholder),
            ),
          ),
        ),
      ],
    );
  }
}
