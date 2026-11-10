import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/date_labels.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../domain/weekly_report.dart';
import 'weekly_report_insight_cards.dart';
import 'weekly_report_stat_row.dart';

/// 주간 리포트 본문: 돌아보기 카드(있을 때) > `한 주 기록`: 숫자 3개 > 요일별 막대 > 일과별 기록 > 자주 남은 카드
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
    final insights = report.insights;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (insights != null) ...[
          WeeklyReportInsightCards(insights: insights),
          SizedBox(height: _groupGap.h),
        ],
        Padding(
          padding: EdgeInsets.only(left: context.space.xs.w, bottom: context.space.xs.h),
          child: Text(
            l10n.weeklyReportRecordSection,
            style: context.typo.settingsGroupLabel.copyWith(color: context.colors.settingsGroupLabel),
          ),
        ),
        WeeklyReportStatRow(report: report),
        SizedBox(height: _groupGap.h),
        _DayBars(days: report.days),
        if (report.routines.isNotEmpty) ...[
          SizedBox(height: _groupGap.h),
          SettingsGroup(
            header: l10n.weeklyReportRoutinesSection,
            children: [for (final routine in report.routines) _RoutineRecordRow(routine: routine)],
          ),
        ],
        if (report.remainingSteps.isNotEmpty) ...[
          SizedBox(height: _groupGap.h),
          SettingsGroup(
            header: l10n.weeklyReportRemainingSection,
            children: [for (final step in report.remainingSteps) _RemainingCardRow(step: step)],
          ),
        ],
      ],
    );
  }
}

/// 요일별 막대 7개: 마친 비율만큼 민트, 마친 일과가 없거나 보낸 일과가 없으면 짧은 회색 막대
class _DayBars extends StatelessWidget {
  const _DayBars({required this.days});

  final List<WeeklyReportDay> days;

  static const _barAreaHeight = 96.0;
  static const _barGap = 8.0;
  static const _barRadius = 8.0;
  static const _weekdayGap = 8.0;

  /// 막대 높이 비율 하한: 마친 일이 있으면 [_doneMinFactor], 없으면 [_emptyFactor]
  static const _doneMinFactor = 0.2;
  static const _emptyFactor = 0.1;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final day in days)
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: (_barGap / 2).w),
              child: Column(
                children: [
                  SizedBox(
                    height: _barAreaHeight.h,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: _heightFactorOf(day),
                        widthFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: day.completedCount > 0 ? colors.routineRingProgress : colors.routineTileBg,
                            borderRadius: BorderRadius.circular(_barRadius.r),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: _weekdayGap.h),
                  Text(
                    context.l10n.weekdayShortOf(day.date),
                    style: context.typo.creditCaption.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  double _heightFactorOf(WeeklyReportDay day) {
    if (day.sentCount == 0 || day.completedCount == 0) return _emptyFactor;
    return day.completionRatio.clamp(_doneMinFactor, 1.0);
  }
}

/// 일과 한 줄: 이름 · `5번 중 4번` + 아래 진행 막대
class _RoutineRecordRow extends StatelessWidget {
  const _RoutineRecordRow({required this.routine});

  final WeeklyReportRoutine routine;

  static const _barHeight = 8.0;
  static const _barRadius = 4.0;
  static const _titleToBar = 8.0;
  static const _padLeft = 20.0;
  static const _padRight = 16.0;
  static const _padVertical = 12.0;
  static const _titleToValue = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ratio = routine.sentCount == 0 ? 0.0 : (routine.completedCount / routine.sentCount).clamp(0.0, 1.0);
    return Padding(
      padding: EdgeInsets.fromLTRB(_padLeft.w, _padVertical.h, _padRight.w, _padVertical.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  routine.title,
                  style: context.typo.settingsTileLabel.copyWith(color: colors.settingsCardLabel),
                ),
              ),
              SizedBox(width: _titleToValue.w),
              Text(
                context.l10n.weeklyReportRoutineRatio(routine.sentCount, routine.completedCount),
                style: context.typo.creditBody.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
          SizedBox(height: _titleToBar.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(_barRadius.r),
            child: SizedBox(
              height: _barHeight.h,
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: colors.routineTileBg)),
                  FractionallySizedBox(
                    widthFactor: ratio,
                    heightFactor: 1,
                    child: ColoredBox(color: colors.routineRingProgress),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 남은 카드 한 줄: 카드 이름 · `3번`
class _RemainingCardRow extends StatelessWidget {
  const _RemainingCardRow({required this.step});

  final WeeklyReportRemainingStep step;

  static const _padLeft = 20.0;
  static const _padRight = 16.0;
  static const _padVertical = 12.0;
  static const _titleToValue = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(_padLeft.w, _padVertical.h, _padRight.w, _padVertical.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              step.stepTitle,
              style: context.typo.settingsTileLabel.copyWith(color: colors.settingsCardLabel),
            ),
          ),
          SizedBox(width: _titleToValue.w),
          Text(
            context.l10n.weeklyReportTimes(step.remainingCount),
            style: context.typo.creditBody.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
