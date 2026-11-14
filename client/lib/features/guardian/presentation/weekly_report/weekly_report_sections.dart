import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_animated_fraction.dart';
import '../../../../core/widgets/app_reveal.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../domain/weekly_report.dart';
import '../../domain/weekly_report_trend.dart';
import 'weekly_report_day_bars.dart';
import 'weekly_report_insight_cards.dart';
import 'weekly_report_stat_row.dart';
import 'weekly_report_summary_donut.dart';
import 'weekly_report_trend_card.dart';
import 'weekly_report_trend_section.dart';

/// 주간 리포트 본문: 완료율 도넛 > 요일별 막대 > 돌아보기 카드(있을 때) > `한 주 기록`: 숫자 > 주별 추이 > 일과별 기록 > 자주 남은 카드
///
/// 사실(횟수)만 보여 준다 — 평가 문구·색으로 잘하고 못함을 가르지 않는다.
/// 끝낸 일과가 0개인 주는 돌아보기 · 숫자 대신 [noCompletionCard] (있을 때, #1302)
class WeeklyReportSections extends StatelessWidget {
  const WeeklyReportSections({super.key, required this.report, this.sampleTrendPoints, this.noCompletionCard});

  final WeeklyReport report;

  /// 끝낸 일과 0개인 주에 숫자 칸 자리를 대신할 빈 카드. null 이면 숫자 칸 그대로
  final Widget? noCompletionCard;

  /// 견본 화면용 주별 추이 점. null 이면 지난 리포트 목록으로 그린다
  final List<WeeklyReportTrendPoint>? sampleTrendPoints;

  /// 묶음 사이 (설정 묶음 간격 16)
  static const _groupGap = 16.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final insights = report.insights;
    final sampleTrendPoints = this.sampleTrendPoints;
    final noCompletionCard = report.completedRoutineCount == 0 ? this.noCompletionCard : null;
    // 묶음이 위에서부터 차례로 떠오름 (빈 간격은 순번에서 빠짐)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: revealInOrder([
        WeeklyReportSummaryDonut(report: report),
        SizedBox(height: _groupGap.h),
        if (noCompletionCard != null) ...[
          noCompletionCard,
          SizedBox(height: _groupGap.h),
          WeeklyReportDayBars(days: report.days),
        ] else ...[
          // 가장 보고 싶은 요일별 막대를 첫 화면 안에 (#1302)
          WeeklyReportDayBars(days: report.days),
          SizedBox(height: _groupGap.h),
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
        ],
        if (sampleTrendPoints != null) ...[
          SizedBox(height: _groupGap.h),
          WeeklyReportTrendCard(points: sampleTrendPoints, highlightedWeekStart: report.weekStart),
        ] else
          WeeklyReportTrendSection(report: report),
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
      ]),
    );
  }
}

/// 일과 한 줄: 이름 · `5번 중 4번` + 아래 진행 막대 (전부 끝냄 민트 · 일부 연한 민트 · 0 회색 받침만)
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

  /// 일부 끝낸 막대 민트 투명도
  static const _partialAlpha = 0.55;

  Color _barColorOf(AppColors colors, double ratio) =>
      ratio >= 1 ? colors.routineRingProgress : colors.routineRingProgress.withValues(alpha: _partialAlpha);

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
                  // 왼쪽에서 차오름
                  AppAnimatedFraction(
                    value: ratio,
                    builder: (context, fraction) => FractionallySizedBox(
                      widthFactor: fraction,
                      heightFactor: 1,
                      child: ColoredBox(color: _barColorOf(colors, ratio)),
                    ),
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
