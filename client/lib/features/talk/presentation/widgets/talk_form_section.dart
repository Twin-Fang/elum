import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';

/// 이야기 폼 구역: 구역 이름(회색, 기본 600/14 · 올리기 · 고치기 500/16) > 내용
/// 올리기 · 고치기 · 가져오기 시트가 함께 쓴다
class TalkFormSection extends StatelessWidget {
  const TalkFormSection({
    super.key,
    required this.label,
    required this.child,
    this.labelStyle,
    this.labelToChildSpacing = defaultLabelToChildSpacing,
  });

  final String label;
  final Widget child;

  /// 구역 이름 글자. null 이면 600/14 (올리기 · 고치기는 시안 500/16)
  final TextStyle? labelStyle;

  /// 이름 > 내용
  final double labelToChildSpacing;

  static const defaultLabelToChildSpacing = 12.0;

  /// 올리기 · 고치기: 이름 > 입력칸 9 · 이름 > 칩 · 카드 격자 16 (시안 1870:9448 > 9449, 1870:9458 > 9475)
  static const labelToFieldSpacing = 9.0;
  static const labelToChoicesSpacing = 16.0;

  /// 구역 이름이 내용보다 더 들어가는 폭
  static const _labelInset = 8.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _labelInset.w),
          child: Text(
            label,
            style: (labelStyle ?? context.typo.talkFormLabel).copyWith(
              color: context.colors.talkMetaText,
            ),
          ),
        ),
        SizedBox(height: labelToChildSpacing.h),
        child,
      ],
    );
  }
}
