import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/logger/app_logger.dart';
import '../../application/weekly_report_providers.dart';
import '../../domain/weekly_report.dart';
import '../../domain/weekly_report_trend.dart';
import 'weekly_report_trend_card.dart';

/// 주별 추이 구역: 지난 리포트 목록 > [WeeklyReportTrendCard]
///
/// 불러오는 중 · 실패 · 2주 미만이면 카드만 숨긴다 (화면의 나머지는 그대로, 실패는 로그만).
class WeeklyReportTrendSection extends ConsumerWidget {
  const WeeklyReportTrendSection({super.key, required this.report});

  final WeeklyReport report;

  /// 위 구역과의 간격 (카드가 보일 때만)
  static const _topGap = 16.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeksAsync = ref.watch(weeklyReportWeeksProvider);
    if (weeksAsync.hasError) {
      AppLogger.error('weekly report trend', weeksAsync.error, weeksAsync.stackTrace);
      return const SizedBox.shrink();
    }
    final weeks = weeksAsync.value;
    if (weeks == null) return const SizedBox.shrink();
    final points = buildWeeklyReportTrendPoints(weeks: weeks.weeks, report: report);
    if (points.length < weeklyReportTrendMinWeekCount) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: _topGap.h),
      child: WeeklyReportTrendCard(points: points, highlightedWeekStart: report.weekStart),
    );
  }
}
