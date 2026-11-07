import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/min_tap_target.dart';
import '../../../../core/widgets/pro_badge.dart';

/// 일과관리 머리 오른쪽 입구 알약 (`주간 계획` · `전문가 일과`): 웜그레이 알약 + 아이콘 12 + 14/500 (시안 「보기 전환」 결 1813:7665, #782)
///
/// 두 입구가 같은 모양 (아이콘 있음 · Free 에게 권하는 중이면 글 뒤 [ProBadge], #1170)
class LibraryEntryPill extends StatelessWidget {
  const LibraryEntryPill({
    super.key,
    required this.label,
    required this.iconAsset,
    required this.onTap,
    this.shouldShowProBadge = false,
  });

  final String label;
  final String iconAsset;
  final VoidCallback onTap;

  /// Free 라 들어가면 흐린 미리 보기인 입구 (`PlanAccess.shouldShowTeaserFor`)
  final bool shouldShowProBadge;

  /// 안쪽 위아래 10 · 좌우 16 · 아이콘 12 · 아이콘 > 글 4 · 글 > 배지 6 · 알약 모서리 100
  static const _paddingVertical = 10.0;
  static const _paddingHorizontal = 16.0;
  static const _iconSize = 12.0;
  static const _iconToText = 4.0;
  static const _textToBadge = 6.0;
  static const _pillRadius = 100.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MinTapTarget(
      child: AppPressable(
        onTap: onTap,
        scaleDown: AppPressable.scaleIcon,
        semanticLabel: label,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: _paddingHorizontal.w,
            vertical: _paddingVertical.h,
          ),
          decoration: BoxDecoration(
            color: colors.routineTileBg,
            borderRadius: BorderRadius.circular(_pillRadius.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                iconAsset,
                width: _iconSize.w,
                height: _iconSize.w,
                excludeFromSemantics: true,
                colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
              ),
              SizedBox(width: _iconToText.w),
              Text(
                label,
                maxLines: 1,
                style: context.typo.chipLabel.copyWith(color: colors.textPrimary),
              ),
              if (shouldShowProBadge) ...[
                SizedBox(width: _textToBadge.w),
                const ProBadge(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
