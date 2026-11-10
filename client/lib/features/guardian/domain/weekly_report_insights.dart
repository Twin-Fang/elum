import 'package:flutter/foundation.dart';

/// 주간 리포트 돌아보기 — 서버 `insights` (칸마다 없을 수 있음)
///
/// 모양이 다르거나 모르는 값이면 그 칸만 null (예외 없이 그 카드만 안 보임).
@immutable
class WeeklyReportInsights {
  const WeeklyReportInsights({this.highlight, this.stuck, this.trend, this.duration, this.slowestStep});

  final WeeklyReportHighlight? highlight;
  final WeeklyReportStuck? stuck;
  final WeeklyReportTrend? trend;
  final WeeklyReportDuration? duration;
  final WeeklyReportSlowestStep? slowestStep;

  /// 보일 카드가 하나도 없는가
  bool get isEmpty =>
      highlight == null && stuck == null && trend == null && duration == null && slowestStep == null;

  static WeeklyReportInsights? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final insights = WeeklyReportInsights(
      highlight: WeeklyReportHighlight.tryParse(raw['highlight']),
      stuck: WeeklyReportStuck.tryParse(raw['stuck']),
      trend: WeeklyReportTrend.tryParse(raw['trend']),
      duration: WeeklyReportDuration.tryParse(raw['duration']),
      slowestStep: WeeklyReportSlowestStep.tryParse(raw['slowestStep']),
    );
    return insights.isEmpty ? null : insights;
  }
}

/// 잘한 것 종류: 처음 끝까지 / 매번 끝까지 / 연속 일수
enum WeeklyReportHighlightKind {
  firstTimeCompleted,
  everyTimeCompleted,
  longestStreak;

  static WeeklyReportHighlightKind? fromWire(Object? raw) => switch (raw) {
    'FIRST_TIME_COMPLETED' => firstTimeCompleted,
    'EVERY_TIME_COMPLETED' => everyTimeCompleted,
    'LONGEST_STREAK' => longestStreak,
    _ => null,
  };
}

@immutable
class WeeklyReportHighlight {
  const WeeklyReportHighlight({
    required this.kind,
    required this.routineTitle,
    required this.completedCount,
    required this.streakDays,
  });

  final WeeklyReportHighlightKind kind;
  final String routineTitle;
  final int completedCount;
  final int streakDays;

  static WeeklyReportHighlight? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final kind = WeeklyReportHighlightKind.fromWire(raw['kind']);
    if (kind == null) return null;
    final routineTitle = _textOrEmpty(raw['routineTitle']);
    final completedCount = _intOrZero(raw['completedCount']);
    final streakDays = _intOrZero(raw['streakDays']);
    // 문장에 들어갈 값이 없으면 카드를 안 그림
    final hasValue = switch (kind) {
      WeeklyReportHighlightKind.firstTimeCompleted => routineTitle.isNotEmpty,
      WeeklyReportHighlightKind.everyTimeCompleted => routineTitle.isNotEmpty && completedCount > 0,
      WeeklyReportHighlightKind.longestStreak => streakDays > 0,
    };
    if (!hasValue) return null;
    return WeeklyReportHighlight(
      kind: kind,
      routineTitle: routineTitle,
      completedCount: completedCount,
      streakDays: streakDays,
    );
  }
}

/// 자주 멈춘 곳 조언 종류
enum WeeklyReportStuckSuggestion {
  shortenOrSplit,
  addVoiceOrPhoto;

  static WeeklyReportStuckSuggestion? fromWire(Object? raw) => switch (raw) {
    'SHORTEN_OR_SPLIT' => shortenOrSplit,
    'ADD_VOICE_OR_PHOTO' => addVoiceOrPhoto,
    _ => null,
  };
}

@immutable
class WeeklyReportStuck {
  const WeeklyReportStuck({
    required this.routineTitle,
    required this.stepTitle,
    required this.remainedCount,
    required this.sentCount,
    required this.suggestion,
    this.libraryRoutineId,
  });

  /// 카드 고치기로 들어갈 원본 일과 id (없으면 버튼 없음)
  final String? libraryRoutineId;
  final String routineTitle;
  final String stepTitle;
  final int remainedCount;
  final int sentCount;
  final WeeklyReportStuckSuggestion suggestion;

  static WeeklyReportStuck? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final suggestion = WeeklyReportStuckSuggestion.fromWire(raw['suggestion']);
    final routineTitle = _textOrEmpty(raw['routineTitle']);
    final stepTitle = _textOrEmpty(raw['stepTitle']);
    if (suggestion == null || routineTitle.isEmpty || stepTitle.isEmpty) return null;
    final libraryRoutineId = _textOrEmpty(raw['libraryRoutineId']);
    return WeeklyReportStuck(
      libraryRoutineId: libraryRoutineId.isEmpty ? null : libraryRoutineId,
      routineTitle: routineTitle,
      stepTitle: stepTitle,
      remainedCount: _intOrZero(raw['remainedCount']),
      sentCount: _intOrZero(raw['sentCount']),
      suggestion: suggestion,
    );
  }
}

/// 지난주 > 이번 주 끝낸 일과 수
@immutable
class WeeklyReportTrend {
  const WeeklyReportTrend({required this.previousCompletedCount, required this.currentCompletedCount});

  final int previousCompletedCount;
  final int currentCompletedCount;

  static WeeklyReportTrend? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final previous = raw['previousCompletedRoutineCount'];
    final current = raw['currentCompletedRoutineCount'];
    if (previous is! num || current is! num) return null;
    return WeeklyReportTrend(previousCompletedCount: previous.toInt(), currentCompletedCount: current.toInt());
  }
}

/// 일과 하나의 평균 걸린 시간 (분): 지난주 > 이번 주
@immutable
class WeeklyReportDuration {
  const WeeklyReportDuration({
    required this.routineTitle,
    required this.previousAverageMinutes,
    required this.currentAverageMinutes,
  });

  final String routineTitle;
  final int previousAverageMinutes;
  final int currentAverageMinutes;

  static WeeklyReportDuration? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final routineTitle = _textOrEmpty(raw['routineTitle']);
    final previous = raw['previousAverageMinutes'];
    final current = raw['currentAverageMinutes'];
    if (routineTitle.isEmpty || previous is! num || current is! num) return null;
    return WeeklyReportDuration(
      routineTitle: routineTitle,
      previousAverageMinutes: previous.toInt(),
      currentAverageMinutes: current.toInt(),
    );
  }
}

/// 가장 오래 머문 카드 (평균 분)
@immutable
class WeeklyReportSlowestStep {
  const WeeklyReportSlowestStep({required this.routineTitle, required this.stepTitle, required this.averageMinutes});

  final String routineTitle;
  final String stepTitle;
  final int averageMinutes;

  static WeeklyReportSlowestStep? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final routineTitle = _textOrEmpty(raw['routineTitle']);
    final stepTitle = _textOrEmpty(raw['stepTitle']);
    final averageMinutes = raw['averageMinutes'];
    if (routineTitle.isEmpty || stepTitle.isEmpty || averageMinutes is! num) return null;
    return WeeklyReportSlowestStep(
      routineTitle: routineTitle,
      stepTitle: stepTitle,
      averageMinutes: averageMinutes.toInt(),
    );
  }
}

String _textOrEmpty(Object? raw) => raw is String ? raw.trim() : '';

int _intOrZero(Object? raw) => raw is num ? raw.toInt() : 0;
