import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/l10n_context.dart';
import '../theme/theme_context_ext.dart';

/// FREE 배지: 민트 바탕 알약 + 점 + `FREE` ([ProBadge] 와 같은 높이·모양, 내 크레딧 머리의 요금제 태그)
class FreeBadge extends StatelessWidget {
  const FreeBadge({super.key});

  /// 안쪽 여백 가로 8 · 세로 4 ([ProBadge] 와 같음), 점 > 글자 6, 점 지름 6
  static const _padH = 8.0;
  static const _padV = 4.0;
  static const _dotToLabel = 6.0;
  static const _dotSize = 6.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = context.l10n.planFreeBadge;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: _padH.w, vertical: _padV.h),
        decoration: BoxDecoration(
          color: colors.proPlanFreeBadgeFill,
          borderRadius: BorderRadius.circular(context.space.pillRadius.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: colors.proPlanFreeBadgeText, shape: BoxShape.circle),
              child: SizedBox(width: _dotSize.w, height: _dotSize.w),
            ),
            SizedBox(width: _dotToLabel.w),
            Text(label, maxLines: 1, style: context.typo.proPlanBadgeLabel.copyWith(color: colors.proPlanFreeBadgeText)),
          ],
        ),
      ),
    );
  }
}
