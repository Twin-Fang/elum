import 'package:flutter/foundation.dart';

/// 일과 알림 1건 (#777): 어떤 일과를 몇 시에, 매일인지
///
/// 이 기기에만 예약된다 — 서버에 저장하지 않는다.
@immutable
class RoutineReminder {
  const RoutineReminder({
    required this.routineId,
    required this.routineTitle,
    required this.hour,
    required this.minute,
    required this.isDaily,
  });

  final String routineId;

  /// 알림 글에 넣을 일과 제목 (예약 시점 값)
  final String routineTitle;

  /// 0~23
  final int hour;

  /// 0~59
  final int minute;

  /// true 매일 같은 시각, false 다음 한 번만
  final bool isDaily;

  /// 저장 JSON > 알림. 값이 깨졌으면 null (그 건만 버린다)
  static RoutineReminder? tryFromJson(String routineId, Object? json) {
    if (json is! Map) return null;
    final hour = json['hour'];
    final minute = json['minute'];
    if (hour is! int || minute is! int) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return RoutineReminder(
      routineId: routineId,
      routineTitle: json['title']?.toString() ?? '',
      hour: hour,
      minute: minute,
      isDaily: json['isDaily'] != false,
    );
  }

  Map<String, Object> toJson() => {
    'title': routineTitle,
    'hour': hour,
    'minute': minute,
    'isDaily': isDaily,
  };

  /// [now] 기준 다음 울릴 시각 (지났으면 내일 같은 시각)
  DateTime nextFireAfter(DateTime now) {
    final today = DateTime(now.year, now.month, now.day, hour, minute);
    return today.isAfter(now) ? today : today.add(const Duration(days: 1));
  }

  /// 일과 id > 알림 id (실행마다 같은 값이어야 해서 String.hashCode 대신 FNV-1a, 31비트 양수)
  int get notificationId {
    var hash = 0x811c9dc5;
    for (final unit in routineId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}
