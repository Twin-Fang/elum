import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/date_labels.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/settings_tile.dart';

/// 주 고르기 줄: `‹  이번 주 · 11월 2일 ~ 11월 8일  ›` (흰 판 r20, 설정 줄 높이 56)
///
/// 이번 주에서는 `›` 자리만 남기고 숨김 (미래 주는 없음)
class WeeklyReportWeekPicker extends StatelessWidget {
  const WeeklyReportWeekPicker({
    super.key,
    required this.weekStart,
    required this.isCurrentWeek,
    required this.onPreviousWeek,
    required this.onNextWeek,
  });

  /// 보고 있는 주 월요일
  final DateTime weekStart;
  final bool isCurrentWeek;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;

  /// 화살표 누름 영역 44 (그림 24)
  static const _arrowTapSize = 44.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + DateTime.daysPerWeek - 1);
    final range = l10n.weekRangeOf(weekStart, weekEnd);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.settingsGroupBg,
        borderRadius: BorderRadius.circular(context.space.cardRadius.r),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: SettingsTile.cardHeight.h),
        child: Row(
          children: [
            _WeekArrow(
              isForward: false,
              semanticLabel: l10n.weeklyReportPreviousWeek,
              onTap: onPreviousWeek,
            ),
            Expanded(
              child: Text(
                isCurrentWeek ? l10n.weeklyReportThisWeekRange(range) : range,
                textAlign: TextAlign.center,
                style: context.typo.settingsTileLabel.copyWith(color: colors.settingsCardLabel),
              ),
            ),
            Visibility(
              visible: !isCurrentWeek,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: _WeekArrow(
                isForward: true,
                semanticLabel: l10n.weeklyReportNextWeek,
                onTap: onNextWeek,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 설정 줄 꺾쇠와 같은 그림(fi-br-angle-small)을 돌려 `‹` · `›` 로 씀
class _WeekArrow extends StatelessWidget {
  const _WeekArrow({required this.isForward, required this.semanticLabel, required this.onTap});

  final bool isForward;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleIcon,
      semanticLabel: semanticLabel,
      child: SizedBox(
        width: WeeklyReportWeekPicker._arrowTapSize.w,
        height: WeeklyReportWeekPicker._arrowTapSize.w,
        child: Center(
          child: Transform.rotate(
            // 원본이 아래를 봄 > 반시계 90° = `›`, 시계 90° = `‹`
            angle: isForward ? -math.pi / 2 : math.pi / 2,
            child: SvgPicture.asset(
              AppAssets.iconAngleSmall,
              width: SettingsTile.cardChevronSize.w,
              height: SettingsTile.cardChevronSize.w,
              colorFilter: ColorFilter.mode(context.colors.settingsChevron, BlendMode.srcIn),
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    );
  }
}
