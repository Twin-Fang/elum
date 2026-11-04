import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/date_labels.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/routine_progress_ring.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../../core/widgets/settings_tile.dart';
import '../../domain/weekly_report.dart';

/// 주간 리포트 본문 묶음 4개: 요약(완료율·하루 링) > 한 주 기록 > 일과별 > 남은 카드
///
/// 사실(횟수)만 보여 준다 — 평가 문구·색으로 잘하고 못함을 가르지 않는다.
class WeeklyReportSections extends StatelessWidget {
  const WeeklyReportSections({super.key, required this.report});

  final WeeklyReport report;

  /// 묶음 사이 (설정 묶음 간격 16)
  static const _groupGap = 16.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryCard(report: report),
        SizedBox(height: _groupGap.h),
        SettingsGroup(
          header: l10n.weeklyReportFactsSection,
          children: [
            SettingsTile(label: l10n.weeklyReportStars, valueText: l10n.weeklyReportCount(report.starsEarned), onTap: null),
            SettingsTile(
              label: l10n.weeklyReportRewards,
              valueText: l10n.weeklyReportCount(report.rewardReachedCount),
              onTap: null,
            ),
            SettingsTile(
              label: l10n.weeklyReportStreak,
              valueText: l10n.weeklyReportDays(report.longestCompletedDayStreak),
              onTap: null,
            ),
          ],
        ),
        if (report.routines.isNotEmpty) ...[
          SizedBox(height: _groupGap.h),
          SettingsGroup(
            header: l10n.weeklyReportRoutinesSection,
            children: [
              for (final routine in report.routines)
                SettingsTile(
                  label: routine.title,
                  valueText: l10n.weeklyReportRoutineValue(routine.sentCount, routine.completedCount),
                  onTap: null,
                ),
            ],
          ),
        ],
        if (report.remainingSteps.isNotEmpty) ...[
          SizedBox(height: _groupGap.h),
          SettingsGroup(
            header: l10n.weeklyReportRemainingSection,
            footer: l10n.weeklyReportRemainingFooter,
            children: [
              for (final step in report.remainingSteps)
                SettingsTile(
                  label: l10n.weeklyReportRemainingLabel(step.routineTitle, step.stepTitle),
                  valueText: l10n.weeklyReportTimes(step.remainingCount),
                  onTap: null,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 요약 카드: 큰 숫자 하나(완료율) + 한 줄 + 월~일 링 7개 (흰 판 r20, 안쪽 20)
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.report});

  final WeeklyReport report;

  static const _padding = 20.0;
  static const _numberToUnit = 8.0;
  static const _numberToSummary = 8.0;
  static const _summaryToDays = 20.0;
  static const _weekdayToRing = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final muted = colors.settingsGroupLabel;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.settingsGroupBg,
        borderRadius: BorderRadius.circular(context.space.cardRadius.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(_padding.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  l10n.weeklyReportPercent(report.completionPercent),
                  style: context.typo.creditNumber.copyWith(color: colors.textPrimary),
                ),
                SizedBox(width: _numberToUnit.w),
                Flexible(
                  child: Text(l10n.weeklyReportCompletionLabel, style: context.typo.creditUnit.copyWith(color: muted)),
                ),
              ],
            ),
            SizedBox(height: _numberToSummary.h),
            Text(
              l10n.weeklyReportCompletionSummary(report.sentRoutineCount, report.completedRoutineCount),
              style: context.typo.creditBody.copyWith(color: colors.settingsCardLabel),
            ),
            SizedBox(height: _summaryToDays.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final day in report.days)
                  Column(
                    children: [
                      Text(l10n.weekdayShortOf(day.date), style: context.typo.creditCaption.copyWith(color: muted)),
                      SizedBox(height: _weekdayToRing.h),
                      _DayMark(day: day),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 하루 표시: 보낸 일과가 있으면 진행 링(마친 비율), 없으면 `-` (링과 같은 자리)
class _DayMark extends StatelessWidget {
  const _DayMark({required this.day});

  final WeeklyReportDay day;

  /// 진행 링 지름 (RoutineProgressRing 40)
  static const _ringSize = 40.0;

  @override
  Widget build(BuildContext context) {
    if (day.sentCount == 0) {
      return SizedBox(
        width: _ringSize.w,
        height: _ringSize.w,
        child: Center(
          child: Text(
            context.l10n.weeklyReportDayNone,
            style: context.typo.creditCaption.copyWith(color: context.colors.settingsGroupLabel),
          ),
        ),
      );
    }
    return RoutineProgressRing(progress: day.completionRatio);
  }
}
