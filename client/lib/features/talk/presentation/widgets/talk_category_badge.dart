import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';

/// 분류 이름표: 피드 카드·상세 머리가 함께 쓴다 (반지름 8, 안쪽 12×6, 시안 1783:6726)
class TalkCategoryBadge extends StatelessWidget {
  const TalkCategoryBadge({super.key, required this.label});

  final String label;

  static const _paddingH = 12.0;
  static const _paddingV = 6.0;
  static const _radius = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _paddingH.w,
        vertical: _paddingV.h,
      ),
      decoration: BoxDecoration(
        color: colors.editChipBg,
        borderRadius: BorderRadius.circular(_radius.r),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: context.typo.talkCategoryLabel.copyWith(
          color: colors.talkTitleText,
        ),
      ),
    );
  }
}
