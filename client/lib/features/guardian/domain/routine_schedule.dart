import 'package:flutter/foundation.dart';

/// 서버 요일 이름 (`DayOfWeek`) — `DateTime.weekday`(1=월 … 7=일) 순서
const _weekdayWires = [
  'MONDAY',
  'TUESDAY',
  'WEDNESDAY',
  'THURSDAY',
  'FRIDAY',
  'SATURDAY',
  'SUNDAY',
];

/// 일과 하나의 반복 요일·시각 — 서버 `RoutineScheduleResponse` (#782, #1080)
///
/// [weekdays] 는 `DateTime.weekday` 값(1=월 … 7=일). 시각은 한국 시각 기준 (서버가 그 시각에 오늘 일과를 만들고 알린다).
@immutable
class RoutineSchedule {
  const RoutineSchedule({
    required this.routineId,
    required this.weekdays,
    required this.hour,
    required this.minute,
    this.isNotifyEnabled = true,
    this.isPaused = false,
  });

  final String routineId;
  final Set<int> weekdays;
  final int hour;
  final int minute;

  /// 그 시각에 이룸이 기기에 알림을 보내는가
  final bool isNotifyEnabled;

  /// 저장한 보호자의 Pro 가 끝나 멈춤 (예약은 남아 있음)
  final bool isPaused;

  /// 시각 정렬 값 (분)
  int get minuteOfDay => hour * 60 + minute;

  bool isOn(int weekday) => weekdays.contains(weekday);

  /// 서버로 보낼 요일 이름 (월요일부터)
  List<String> get weekdayWires => [
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
      if (weekdays.contains(weekday)) _weekdayWires[weekday - 1],
  ];

  /// 서버로 보낼 시각 `HH:mm`
  String get timeWire =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// 응답 모양이 어긋나면 null (목록에서 빠짐, 화면은 죽지 않음)
  static RoutineSchedule? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final routineId = json['routineId']?.toString() ?? '';
    final timeParts = (json['time']?.toString() ?? '').split(':');
    if (routineId.isEmpty || timeParts.length < 2) return null;
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null || minute == null) return null;
    final weekdays = <int>{
      if (json['weekdays'] case final List<dynamic> names)
        for (final name in names)
          if (_weekdayWires.indexOf(name.toString()) case final index
              when index >= 0)
            index + 1,
    };
    if (weekdays.isEmpty) return null;
    return RoutineSchedule(
      routineId: routineId,
      weekdays: weekdays,
      hour: hour,
      minute: minute,
      isNotifyEnabled: json['notifyEnabled'] != false,
      isPaused: json['paused'] == true,
    );
  }
}

/// 이룸이 기기 알림 상태 — 서버 `ElumiNotificationState`
enum ElumiNotificationState {
  /// 연결된 이룸이 기기가 없다
  noDevice('NO_DEVICE'),

  /// 연결됐지만 알림이 꺼져 있다 (알림 토큰이 등록되지 않음)
  off('OFF'),
  on('ON');

  const ElumiNotificationState(this.wire);

  final String wire;

  /// 모르는 값은 켜짐으로 본다 — 확실하지 않은데 "꺼져 있어요"로 겁주지 않는다
  static ElumiNotificationState from(Object? raw) => values.firstWhere(
    (state) => state.wire == raw,
    orElse: () => ElumiNotificationState.on,
  );
}

/// 주간 계획 한 벌 — 서버 `RoutineScheduleListResponse`
@immutable
class RoutineSchedulePlan {
  const RoutineSchedulePlan({
    this.schedules = const [],
    this.canSchedule = false,
    this.elumiNotification = ElumiNotificationState.on,
  });

  /// 시각 순
  final List<RoutineSchedule> schedules;

  /// 서버가 본 이 보호자의 요금제 권한 (새로 정하기·바꾸기)
  final bool canSchedule;

  final ElumiNotificationState elumiNotification;

  bool get hasPausedSchedule => schedules.any((schedule) => schedule.isPaused);

  RoutineSchedule? scheduleOf(String routineId) {
    for (final schedule in schedules) {
      if (schedule.routineId == routineId) return schedule;
    }
    return null;
  }

  /// 그 요일 예약, 시각 순
  List<RoutineSchedule> schedulesOn(int weekday) => [
    for (final schedule in schedules)
      if (schedule.isOn(weekday)) schedule,
  ]..sort((a, b) => a.minuteOfDay.compareTo(b.minuteOfDay));

  static RoutineSchedulePlan fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RoutineSchedulePlan();
    final schedules = [
      if (json['schedules'] case final List<dynamic> list)
        for (final scheduleJson in list) ?RoutineSchedule.tryFromJson(scheduleJson),
    ]..sort((a, b) => a.minuteOfDay.compareTo(b.minuteOfDay));
    return RoutineSchedulePlan(
      schedules: schedules,
      canSchedule: json['canSchedule'] == true,
      elumiNotification: ElumiNotificationState.from(json['elumiNotification']),
    );
  }
}
