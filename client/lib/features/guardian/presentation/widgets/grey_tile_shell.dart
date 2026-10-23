import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';

/// 빈 상태·로딩의 회색 껍데기 (Figma 931:3906 — 361×68, r20, #EEE9E6).
/// 실패를 담을 때의 회색 칸 높이. 한 줄(68)로는 세 줄이 안 들어간다.
const double greyTileErrorShellHeight = 96;

class GreyTileShell extends StatelessWidget {
  const GreyTileShell({super.key, required this.child, this.height});

  final Widget child;

  /// 기본은 일과 한 줄과 같은 68.
  ///
  /// **실패를 담을 때는 늘린다.** 실패는 무엇이 안 됐는지·무엇을 하면 되는지·
  /// 추적 코드까지 세 줄이라 한 줄 높이에 들어가지 않는다 — 실기기에서
  /// 11px 넘쳤다. 늘어나는 것은 실패했을 때뿐이라 평소 리듬은 그대로다.
  final double? height;

  /// 좌우 안쪽 18 (빈 상태·로딩·실패 글 시작 자리)
  static const _paddingHorizontal = 18.0;

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      height: (height ?? 68).h,
      padding: EdgeInsets.symmetric(horizontal: _paddingHorizontal.w),
      decoration: BoxDecoration(
        color: context.colors.routineTileBg,
        borderRadius: BorderRadius.circular(space.cardRadius),
      ),
      child: child,
    );
  }
}
