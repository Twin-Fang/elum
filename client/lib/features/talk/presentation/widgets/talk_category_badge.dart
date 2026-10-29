import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/theme_context_ext.dart';

/// 분류 이름표: 피드 카드·상세 머리가 함께 쓴다 (반지름 8, 안쪽 12×6, 시안 1783:6726)
/// [iconAsset] 이 있으면 글자 앞에 10px 아이콘 (상세 `🃏 4장` 칩, 시안 1813:7571)
class TalkCategoryBadge extends StatelessWidget {
  const TalkCategoryBadge({super.key, required this.label, this.iconAsset});

  final String label;
  final String? iconAsset;

  static const _paddingH = 12.0;
  static const _paddingV = 6.0;
  static const _radius = 8.0;
  static const _iconSize = 10.0;
  static const _iconToLabel = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final iconAsset = this.iconAsset;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _paddingH.w,
        vertical: _paddingV.h,
      ),
      decoration: BoxDecoration(
        color: colors.editChipBg,
        borderRadius: BorderRadius.circular(_radius.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconAsset != null) ...[
            SvgPicture.asset(
              iconAsset,
              width: _iconSize.w,
              height: _iconSize.w,
              colorFilter: ColorFilter.mode(
                colors.talkTitleText,
                BlendMode.srcIn,
              ),
            ),
            SizedBox(width: _iconToLabel.w),
          ],
          Text(
            label,
            maxLines: 1,
            style: context.typo.talkCategoryLabel.copyWith(
              color: colors.talkTitleText,
            ),
          ),
        ],
      ),
    );
  }
}
