import 'package:flutter/material.dart';

import '../../../../core/l10n/date_labels.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../domain/routine_schedule.dart';

/// 반복 줄·주간 계획 공통 문구: 요일 묶음 > `매일`·`평일`·`주말`·`월·수·금`, 시각 > 기기 언어 형식

const _weekdaysOnly = {1, 2, 3, 4, 5};
const _weekendOnly = {6, 7};
const _allDayCount = 7;

/// `월·수·금 오전 8:00` · `매일 오전 8:00`
String routineScheduleSummaryLabel(
  BuildContext context,
  RoutineSchedule schedule,
) => context.l10n.routineScheduleSummary(
  routineScheduleDaysLabel(context, schedule.weekdays),
  routineScheduleTimeLabel(context, schedule),
);

/// 고른 요일 > 묶음 이름이 있으면 그 이름, 아니면 짧은 요일을 월요일부터
String routineScheduleDaysLabel(BuildContext context, Set<int> weekdays) {
  final l10n = context.l10n;
  if (weekdays.length == _allDayCount) return l10n.routineScheduleEveryDay;
  if (_isSameSet(weekdays, _weekdaysOnly)) return l10n.routineScheduleWeekdaysOnly;
  if (_isSameSet(weekdays, _weekendOnly)) return l10n.routineScheduleWeekendOnly;
  final sorted = weekdays.toList()..sort();
  return sorted
      .map(l10n.weekdayShortOfNumber)
      .join(l10n.routineScheduleDaySeparator);
}

/// 시각 > `오전 8:00` (기기 언어 형식)
String routineScheduleTimeLabel(
  BuildContext context,
  RoutineSchedule schedule,
) => MaterialLocalizations.of(context).formatTimeOfDay(
  TimeOfDay(hour: schedule.hour, minute: schedule.minute),
);

bool _isSameSet(Set<int> a, Set<int> b) =>
    a.length == b.length && a.containsAll(b);
