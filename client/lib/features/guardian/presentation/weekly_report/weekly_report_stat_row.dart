import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_count_up.dart';
import '../../domain/weekly_report.dart';

/// 한 주 숫자 5개 (흰 판 r20: 한 색 아이콘 > 값 > 이름)
/// 윗줄 3칸: 끝낸 일과 · 받은 별 · 남은 카드, 아랫줄 2칸: 보상까지 간 일과 · 연속으로 마친 날
class WeeklyReportStatRow extends StatelessWidget {
  const WeeklyReportStatRow({super.key, required this.report});

  final WeeklyReport report;

  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final remainingCardCount = report.remainingSteps.fold<int>(0, (sum, step) => sum + step.remainingCount);
    final topStats = [
      (iconAsset: AppAssets.iconCheckMark, count: report.completedRoutineCount, label: l10n.weeklyReportStatCompleted),
      (iconAsset: AppAssets.starBadge, count: report.starsEarned, label: l10n.weeklyReportStars),
      (iconAsset: AppAssets.iconPlayingCards, count: remainingCardCount, label: l10n.weeklyReportStatRemaining),
    ];
    final bottomStats = [
      (iconAsset: AppAssets.iconFlag, count: report.rewardReachedCount, label: l10n.weeklyReportRewards),
      (iconAsset: AppAssets.iconCalendar, count: report.longestCompletedDayStreak, label: l10n.weeklyReportStreak),
    ];
    return Column(
      children: [
        for (final (rowIndex, stats) in [topStats, bottomStats].indexed) ...[
          if (rowIndex > 0) SizedBox(height: _gap.h),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, stat) in stats.indexed) ...[
                  if (index > 0) SizedBox(width: _gap.w),
                  Expanded(child: _StatBox(iconAsset: stat.iconAsset, count: stat.count, label: stat.label)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.iconAsset, required this.count, required this.label});

  final String iconAsset;
  final int count;
  final String label;

  static const _padding = 12.0;
  static const _iconSize = 18.0;
  static const _iconToCount = 6.0;
  static const _countToLabel = 2.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.settingsGroupBg,
        borderRadius: BorderRadius.circular(context.space.cardRadius.r),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: _padding.h, horizontal: context.space.xs.w),
        child: Column(
          children: [
            SvgPicture.asset(
              iconAsset,
              width: _iconSize.w,
              height: _iconSize.w,
              excludeFromSemantics: true,
              colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
            ),
            SizedBox(height: _iconToCount.h),
            // 0 부터 세며 올라감
            AppCountUp(
              from: 0,
              to: count,
              format: (value) => '$value',
              style: context.typo.subtitle.copyWith(color: colors.textPrimary),
            ),
            SizedBox(height: _countToLabel.h),
            Text(
              label,
              textAlign: TextAlign.center,
              style: context.typo.creditCaption.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
