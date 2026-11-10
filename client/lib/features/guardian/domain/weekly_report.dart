import 'package:flutter/foundation.dart';

import 'weekly_report_insights.dart';

/// 이룸이 한 주 요약 — 서버 `GET /api/routines/weekly-report` (#1074)
///
/// 완료 기록에서 센 사실만 담는다 (원문·보상 문구·평가 없음).
/// 날짜·개수가 빠진 응답은 [FormatException] — 0 으로 채우면 "아무것도 안 했다"로 읽힌다.
@immutable
class WeeklyReport {
  const WeeklyReport({
    required this.weekStart,
    required this.weekEnd,
    required this.isCurrentWeek,
    required this.sentRoutineCount,
    required this.completedRoutineCount,
    required this.completionPercent,
    required this.starsEarned,
    required this.rewardReachedCount,
    required this.longestCompletedDayStreak,
    required this.days,
    required this.routines,
    required this.remainingSteps,
    this.summary,
    this.insights,
  });

  final DateTime weekStart;

  /// 일요일 (포함)
  final DateTime weekEnd;
  final bool isCurrentWeek;
  final int sentRoutineCount;
  final int completedRoutineCount;

  /// 0~100 (마친 일과 / 보낸 일과)
  final int completionPercent;

  /// 이 주 일과에서 마친 카드 수 (카드 1장 = 별 1개)
  final int starsEarned;
  final int rewardReachedCount;

  /// 일과를 하나 이상 마친 날이 이어진 가장 긴 날 수
  final int longestCompletedDayStreak;

  /// 월 ~ 일 7칸
  final List<WeeklyReportDay> days;
  final List<WeeklyReportRoutine> routines;

  /// 지난 날 마치지 않고 남은 카드 (많은 순 최대 3)
  final List<WeeklyReportRemainingStep> remainingSteps;

  /// 루미가 정리한 글 (이번 주·끝낸 일과 없는 주·옛 서버 응답이면 null)
  final WeeklyReportSummary? summary;

  /// 돌아보기 카드 재료 (옛 서버 응답·모양이 다르면 null)
  final WeeklyReportInsights? insights;

  /// 이 주에 보낸 일과가 있는가 (없으면 빈 상태 화면)
  bool get hasRecords => sentRoutineCount > 0;

  factory WeeklyReport.fromJson(Map<String, dynamic> json) {
    return WeeklyReport(
      weekStart: _requireDate(json, 'weekStart'),
      weekEnd: _requireDate(json, 'weekEnd'),
      isCurrentWeek: json['isCurrentWeek'] == true,
      sentRoutineCount: _requireInt(json, 'sentRoutineCount'),
      completedRoutineCount: _requireInt(json, 'completedRoutineCount'),
      completionPercent: _requireInt(json, 'completionPercent').clamp(0, 100),
      starsEarned: _intOrZero(json['starsEarned']),
      rewardReachedCount: _intOrZero(json['rewardReachedCount']),
      longestCompletedDayStreak: _intOrZero(json['longestCompletedDayStreak']),
      days: _listOf(json['days'], WeeklyReportDay.tryParse),
      routines: _listOf(json['routines'], WeeklyReportRoutine.tryParse),
      remainingSteps: _listOf(json['remainingSteps'], WeeklyReportRemainingStep.tryParse),
      summary: WeeklyReportSummary.tryParse(json['summary']),
      insights: WeeklyReportInsights.tryParse(json['insights']),
    );
  }
}

/// 루미 정리 글: 줄 목록 (이름이 이미 들어 있음)
@immutable
class WeeklyReportSummary {
  const WeeklyReportSummary({required this.lines});

  final List<String> lines;

  /// 줄을 이어 붙인 한 문단
  String get paragraph => lines.join(' ');

  /// 비었거나 모양이 다르면 null (정리 글 자리 없이 숫자부터)
  static WeeklyReportSummary? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final rawLines = raw['lines'];
    if (rawLines is! List<dynamic>) return null;
    final lines = rawLines.whereType<String>().map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
    if (lines.isEmpty) return null;
    return WeeklyReportSummary(lines: lines);
  }
}

/// 하루 칸: 보낸 일과 수 · 마친 일과 수
@immutable
class WeeklyReportDay {
  const WeeklyReportDay({required this.date, required this.sentCount, required this.completedCount});

  final DateTime date;
  final int sentCount;
  final int completedCount;

  /// 0.0 ~ 1.0 (보낸 일과가 없으면 0)
  double get completionRatio => sentCount == 0 ? 0 : completedCount / sentCount;

  static WeeklyReportDay? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final date = DateTime.tryParse('${raw['date']}');
    if (date == null) return null;
    return WeeklyReportDay(
      date: date,
      sentCount: _intOrZero(raw['sentCount']),
      completedCount: _intOrZero(raw['completedCount']),
    );
  }
}

/// 일과 하나 (같은 원본에서 보낸 일과를 묶음): 보낸 횟수 · 마친 횟수
@immutable
class WeeklyReportRoutine {
  const WeeklyReportRoutine({required this.title, required this.sentCount, required this.completedCount});

  final String title;
  final int sentCount;
  final int completedCount;

  static WeeklyReportRoutine? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final title = raw['title'];
    if (title is! String || title.trim().isEmpty) return null;
    return WeeklyReportRoutine(
      title: title,
      sentCount: _intOrZero(raw['sentCount']),
      completedCount: _intOrZero(raw['completedCount']),
    );
  }
}

/// 남은 카드 하나: 어느 일과의 어느 카드가 몇 번 남았나
@immutable
class WeeklyReportRemainingStep {
  const WeeklyReportRemainingStep({
    required this.routineTitle,
    required this.stepTitle,
    required this.remainingCount,
  });

  final String routineTitle;
  final String stepTitle;
  final int remainingCount;

  static WeeklyReportRemainingStep? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final routineTitle = raw['routineTitle'];
    final stepTitle = raw['stepTitle'];
    if (routineTitle is! String || stepTitle is! String) return null;
    return WeeklyReportRemainingStep(
      routineTitle: routineTitle,
      stepTitle: stepTitle,
      remainingCount: _intOrZero(raw['remainingCount']),
    );
  }
}

/// 그 날이 든 주의 월요일 0시 (기기 시각 기준 · 서버도 월요일로 맞춤)
DateTime weekStartOf(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

DateTime _requireDate(Map<String, dynamic> json, String key) {
  final parsed = DateTime.tryParse('${json[key]}');
  if (parsed == null) throw FormatException('weekly report missing $key');
  return parsed;
}

int _requireInt(Map<String, dynamic> json, String key) {
  final rawCount = json[key];
  if (rawCount is! num) throw FormatException('weekly report missing $key');
  return rawCount.toInt();
}

int _intOrZero(Object? rawCount) => rawCount is num ? rawCount.toInt() : 0;

List<T> _listOf<T>(Object? raw, T? Function(Object?) parse) => switch (raw) {
  final List<dynamic> list => list.map(parse).whereType<T>().toList(),
  _ => List<T>.empty(),
};
