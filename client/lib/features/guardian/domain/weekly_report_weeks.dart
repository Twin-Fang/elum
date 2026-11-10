import 'package:flutter/foundation.dart';

/// 지난 리포트 목록 — 서버 `GET /api/routines/weekly-report/weeks`
///
/// 빠졌거나 모양이 다른 응답은 예외 없이 빈 목록 · null.
@immutable
class WeeklyReportWeeks {
  const WeeklyReportWeeks({required this.weeks, this.freePreviewWeekStart});

  /// 최신순
  final List<WeeklyReportWeekEntry> weeks;

  /// Free 에게 미리 보여 주는 주 월요일 (없으면 null)
  final DateTime? freePreviewWeekStart;

  static const empty = WeeklyReportWeeks(weeks: []);

  factory WeeklyReportWeeks.fromJson(Map<String, dynamic> json) {
    final rawWeeks = json['weeks'];
    return WeeklyReportWeeks(
      weeks: rawWeeks is List<dynamic>
          ? rawWeeks.map(WeeklyReportWeekEntry.tryParse).whereType<WeeklyReportWeekEntry>().toList()
          : const [],
      freePreviewWeekStart: _tryParseDate(json['freePreviewWeekStart']),
    );
  }
}

/// 지난 리포트 한 줄: 주 월요일 · 끝낸 일과 수
@immutable
class WeeklyReportWeekEntry {
  const WeeklyReportWeekEntry({required this.weekStart, required this.completedRoutineCount});

  final DateTime weekStart;
  final int completedRoutineCount;

  static WeeklyReportWeekEntry? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final weekStart = _tryParseDate(raw['weekStart']);
    if (weekStart == null) return null;
    final count = raw['completedRoutineCount'];
    return WeeklyReportWeekEntry(weekStart: weekStart, completedRoutineCount: count is num ? count.toInt() : 0);
  }
}

DateTime? _tryParseDate(Object? raw) => raw is String ? DateTime.tryParse(raw) : null;
