import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/min_tap_target.dart';

/// 일과관리 머리 오른쪽 `주간 계획` 알약 (#782): 웜그레이 알약 + 달력 12 + 14/500 (시안 「보기 전환」 결 1813:7665)
class WeeklyPlanEntryPill extends StatelessWidget {
  const WeeklyPlanEntryPill({super.key});

  /// 안쪽 위아래 10 · 좌우 16 · 아이콘 12 · 아이콘 > 글 4 · 알약 모서리 100
  static const _paddingVertical = 10.0;
  static const _paddingHorizontal = 16.0;
  static const _iconSize = 12.0;
  static const _iconToText = 4.0;
  static const _pillRadius = 100.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MinTapTarget(
      child: AppPressable(
        onTap: () => context.push(Routes.guardianWeeklyPlan),
        scaleDown: AppPressable.scaleIcon,
        semanticLabel: context.l10n.weeklyPlanEntry,
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
                AppAssets.iconCalendar,
                width: _iconSize.w,
                height: _iconSize.w,
                excludeFromSemantics: true,
                colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
              ),
              SizedBox(width: _iconToText.w),
              Text(
                context.l10n.weeklyPlanEntry,
                maxLines: 1,
                style: context.typo.chipLabel.copyWith(color: colors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
