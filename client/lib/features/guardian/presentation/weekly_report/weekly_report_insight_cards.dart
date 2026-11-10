import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/batchim.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../application/guardian_child_identity.dart';
import '../../domain/weekly_report_insights.dart';
import 'weekly_report_insight_plate.dart';
import 'weekly_report_open_card_edit.dart';

/// 돌아보기 카드: 잘한 것 > 자주 멈춘 곳 > 지난주와 달라진 점 > 걸린 시간 > 가장 오래 머문 카드 (있는 것만)
///
/// 단정하지 않는 말만 쓴다. 조언은 "~해 볼 수 있어요". 일과·카드 제목은 일과 언어 글 그대로.
class WeeklyReportInsightCards extends ConsumerWidget {
  const WeeklyReportInsightCards({super.key, required this.insights});

  final WeeklyReportInsights insights;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final savedName = ref.watch(guardianChildIdentityProvider.select((identity) => identity.name));
    final elumiName = savedName.isEmpty ? l10n.commonElumiName : savedName;
    final highlight = insights.highlight;
    final stuck = insights.stuck;
    final trend = insights.trend;
    final duration = insights.duration;
    final slowestStep = insights.slowestStep;
    final plates = <Widget>[
      if (highlight != null)
        WeeklyReportInsightPlate(
          fill: colors.weeklyReportInsightGoodFill,
          accent: colors.weeklyReportInsightGoodAccent,
          iconAsset: AppAssets.iconThumbsUp,
          title: l10n.weeklyReportInsightHighlightTitle,
          line: _highlightLine(context, highlight),
          hint: l10n.weeklyReportInsightHighlightHint(elumiName),
        ),
      if (stuck != null)
        WeeklyReportInsightPlate(
          fill: colors.weeklyReportInsightStuckFill,
          accent: colors.weeklyReportInsightStuckAccent,
          iconAsset: AppAssets.iconFlag,
          title: l10n.weeklyReportInsightStuckTitle,
          line: l10n.weeklyReportInsightStuckLine(
            stuck.routineTitle,
            stuck.stepTitle,
            stuck.sentCount,
            stuck.remainedCount,
          ),
          hint: switch (stuck.suggestion) {
            WeeklyReportStuckSuggestion.shortenOrSplit => l10n.weeklyReportInsightStuckShorten,
            WeeklyReportStuckSuggestion.addVoiceOrPhoto => l10n.weeklyReportInsightStuckAddMedia,
          },
          child: switch (stuck.libraryRoutineId) {
            final libraryRoutineId? => WeeklyReportInsightButton(
              label: l10n.weeklyReportInsightStuckFix(stuck.stepTitle),
              onTap: () => openLibraryRoutineCardEdit(context, ref, libraryRoutineId),
            ),
            null => null,
          },
        ),
      if (trend != null)
        WeeklyReportInsightPlate(
          fill: colors.weeklyReportInsightTrendFill,
          accent: colors.weeklyReportInsightTrendAccent,
          iconAsset: AppAssets.iconRefresh,
          title: l10n.weeklyReportInsightTrendTitle,
          line: _trendLine(context, trend),
          child: WeeklyReportTrendBars(
            previousCount: trend.previousCompletedCount,
            currentCount: trend.currentCompletedCount,
            previousLabel: l10n.weeklyReportInsightTrendBarPrevious(trend.previousCompletedCount),
            currentLabel: l10n.weeklyReportInsightTrendBarCurrent(trend.currentCompletedCount),
            currentColor: colors.weeklyReportInsightTrendAccent,
          ),
        ),
      if (duration != null)
        WeeklyReportInsightPlate(
          fill: colors.routineTileBg,
          accent: colors.textSecondary,
          iconAsset: AppAssets.iconTimePast,
          title: l10n.weeklyReportInsightDurationTitle,
          line: l10n.weeklyReportInsightDurationLine(
            duration.routineTitle,
            duration.previousAverageMinutes,
            duration.currentAverageMinutes,
          ),
        ),
      if (slowestStep != null)
        WeeklyReportInsightPlate(
          fill: colors.routineTileBg,
          accent: colors.textSecondary,
          iconAsset: AppAssets.iconPlayingCards,
          title: l10n.weeklyReportInsightSlowestTitle,
          line: l10n.weeklyReportInsightSlowestLine(
            slowestStep.routineTitle,
            slowestStep.stepTitle,
            slowestStep.averageMinutes,
          ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, plate) in plates.indexed) ...[
          if (index > 0) SizedBox(height: context.space.sm.h),
          plate,
        ],
      ],
    );
  }

  /// 잘한 것 종류 > 문장 (조사는 일과 이름 끝 글자로)
  String _highlightLine(BuildContext context, WeeklyReportHighlight highlight) {
    final l10n = context.l10n;
    return switch (highlight.kind) {
      WeeklyReportHighlightKind.firstTimeCompleted => l10n.weeklyReportInsightHighlightFirst(
        highlight.routineTitle,
        batchimOf(highlight.routineTitle),
      ),
      WeeklyReportHighlightKind.everyTimeCompleted => l10n.weeklyReportInsightHighlightEvery(
        highlight.routineTitle,
        batchimOf(highlight.routineTitle),
        highlight.completedCount,
      ),
      WeeklyReportHighlightKind.longestStreak => l10n.weeklyReportInsightHighlightStreak(highlight.streakDays),
    };
  }

  /// 늘면 `늘었어요` · 줄면 `됐어요` · 같으면 `같이`
  String _trendLine(BuildContext context, WeeklyReportTrend trend) {
    final l10n = context.l10n;
    final before = trend.previousCompletedCount;
    final after = trend.currentCompletedCount;
    if (after > before) return l10n.weeklyReportInsightTrendUp(before, after);
    if (after < before) return l10n.weeklyReportInsightTrendDown(before, after);
    return l10n.weeklyReportInsightTrendSame(after);
  }
}
