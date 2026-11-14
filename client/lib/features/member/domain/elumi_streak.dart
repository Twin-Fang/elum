import 'package:flutter/foundation.dart';

/// 이룸이 연속 기록: 이어서 일과를 마친 일수 + 오늘 안 마치면 끊기는지 (서버 하루 유예 판정)
/// 출처: 서버 `MemberResponse.currentStreakDays` · `isStreakAtRiskToday`. 필드 없는 이전 서버면 0 · false
@immutable
class ElumiStreak {
  const ElumiStreak({this.days = 0, this.isAtRiskToday = false});

  static const none = ElumiStreak();

  /// 화면에 보이는 최소 일수 (0 · 1일은 연속이라 부르기 일러 숨김)
  static const minimumVisibleDays = 2;

  /// 축하하는 일수 4개: 3 · 7 · 14 · 30
  static const milestoneDays = [3, 7, 14, 30];

  final int days;

  /// 어제까지 이어졌고 오늘 아직 안 마침 (오늘이 지나면 끊김)
  final bool isAtRiskToday;

  bool get isVisible => days >= minimumVisibleDays;

  /// 지금 일수가 닿은 가장 큰 축하 일수 (없으면 null)
  int? get reachedMilestone => milestoneDays.where((milestone) => milestone <= days).lastOrNull;

  /// 회원 응답 최상위 두 필드 > 연속 기록 (타입이 달라도 예외 없이 0 · false)
  factory ElumiStreak.fromMemberJson(Map<String, dynamic> json) {
    final rawDays = json['currentStreakDays'];
    final days = switch (rawDays) {
      final int value => value,
      final num value => value.toInt(),
      final String value => int.tryParse(value) ?? 0,
      _ => 0,
    };
    return ElumiStreak(
      days: days < 0 ? 0 : days,
      isAtRiskToday: json['isStreakAtRiskToday'] == true,
    );
  }

  @override
  bool operator ==(Object other) => other is ElumiStreak && other.days == days && other.isAtRiskToday == isAtRiskToday;

  @override
  int get hashCode => Object.hash(days, isAtRiskToday);
}
