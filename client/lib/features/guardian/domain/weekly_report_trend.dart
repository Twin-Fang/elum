import 'package:flutter/foundation.dart';

import 'weekly_report.dart';
import 'weekly_report_weeks.dart';

/// 주별 추이 선 그래프의 점 하나: 주 월요일 · 끝낸 일과 수
@immutable
class WeeklyReportTrendPoint {
  const WeeklyReportTrendPoint({required this.weekStart, required this.completedRoutineCount});

  final DateTime weekStart;
  final int completedRoutineCount;
}

/// 그래프에 그릴 최대 주 수
const weeklyReportTrendMaxWeekCount = 6;

/// 그래프에 그릴 최소 주 수 (미만이면 카드를 숨김)
const weeklyReportTrendMinWeekCount = 2;

/// 지난 리포트 목록 > 보고 있는 주까지 최근 최대 6주 (오래된 주부터)
///
/// 목록에 보고 있는 주가 없으면 리포트의 끝낸 일과 수로 그 주를 채운다.
List<WeeklyReportTrendPoint> buildWeeklyReportTrendPoints({
  required List<WeeklyReportWeekEntry> weeks,
  required WeeklyReport report,
}) {
  final pointByWeekStart = <DateTime, WeeklyReportTrendPoint>{
    for (final week in weeks)
      if (!week.weekStart.isAfter(report.weekStart))
        week.weekStart: WeeklyReportTrendPoint(
          weekStart: week.weekStart,
          completedRoutineCount: week.completedRoutineCount,
        ),
    report.weekStart: WeeklyReportTrendPoint(
      weekStart: report.weekStart,
      completedRoutineCount: report.completedRoutineCount,
    ),
  };
  final points = pointByWeekStart.values.toList()..sort((a, b) => a.weekStart.compareTo(b.weekStart));
  return points.length <= weeklyReportTrendMaxWeekCount
      ? points
      : points.sublist(points.length - weeklyReportTrendMaxWeekCount);
}
