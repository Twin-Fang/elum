import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';

/// 이야기 폼 구역: 구역 이름(600/14 회색, 일과 구역 이름 결) > 내용
/// 올리기 · 고치기 · 가져오기 시트가 함께 쓴다
class TalkFormSection extends StatelessWidget {
  const TalkFormSection({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  /// 구역 이름이 내용보다 더 들어가는 폭 · 이름 > 내용
  static const _labelInset = 8.0;
  static const _labelToChild = 12.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _labelInset.w),
          child: Text(
            label,
            style: context.typo.talkFormLabel.copyWith(
              color: context.colors.talkMetaText,
            ),
          ),
        ),
        SizedBox(height: _labelToChild.h),
        child,
      ],
    );
  }
}
