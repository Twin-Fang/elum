import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/theme_context_ext.dart';

/// 별 배지 (Figma 364:8531 — 50×48 SVG 위에 숫자를 겹친다).
class ChildStarBadge extends StatelessWidget {
  const ChildStarBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50.w,
      height: 48.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SvgPicture.asset(AppAssets.starBadge, width: 50.w, height: 48.w),
          Padding(
            // 별 무게중심이 약간 위라 숫자를 살짝 내린다 (Figma y=91-74=17)
            padding: EdgeInsets.only(top: 4.h),
            child: Text(
              '$count',
              style: context.typo.subtitle.copyWith(
                color: context.colors.starCount,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
