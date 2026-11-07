import '../../l10n/app_localizations.dart';

/// `DateTime.weekday`(1=월 … 7=일) → ARB `select` 키.
const _weekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// 이 일수 이상 지나면 "N일 전" 대신 날짜로 적는다
const _maxTimeAgoDays = 7;

/// 날짜·요일 문구. 순서·단위·요일 이름은 언어마다 ARB 가 정한다 — 코드가 `월`·`일` 을 붙이지 않는다.
extension DateLabels on AppLocalizations {
  /// `월` 같은 짧은 요일.
  String weekdayShortOf(DateTime d) => weekdayShortOfNumber(d.weekday);

  /// `DateTime.weekday` 값(1=월 … 7=일) > `월` 같은 짧은 요일 (날짜 없이 요일만 다룰 때)
  String weekdayShortOfNumber(int weekday) => weekdayShort(_weekdayKeys[weekday - 1]);

  /// `2026년 9월 20일`
  String yearMonthDay(DateTime d) => dateYearMonthDay(d.year, d.month, d.day);

  /// 끝나는 시각(그 시각부터 못 씀) > `…까지` 앞에 쓸 마지막 날 (0시 정각 종료면 전날, #1169)
  /// 예: `2027-05-07T00:00` > `2027년 5월 6일`, `2027-05-07T14:30` > `2027년 5월 7일`
  String yearMonthDayUntil(DateTime endsAt) {
    final local = endsAt.toLocal();
    final isMidnightEnd = local.hour == 0 &&
        local.minute == 0 &&
        local.second == 0 &&
        local.millisecond == 0 &&
        local.microsecond == 0;
    // Duration 빼기 대신 날짜 칸을 줄임 (서머타임 날 23시간 하루에도 전날)
    final lastDay = isMidnightEnd
        ? DateTime(local.year, local.month, local.day - 1)
        : local;
    return yearMonthDay(lastDay);
  }

  /// `9월 18일부터`
  String monthDaySince(DateTime d) => dateMonthDaySince(d.month, d.day);

  /// `9월 28일(월) 0시` — 분이 0이면 분을 적지 않는다.
  String resetAt(DateTime d) => d.minute == 0
      ? creditResetAt(d.month, d.day, weekdayShortOf(d), d.hour)
      : creditResetAtMinute(d.month, d.day, weekdayShortOf(d), d.hour, d.minute);

  /// `11월 2일 ~ 11월 8일` (주간 리포트 주 범위)
  String weekRangeOf(DateTime start, DateTime end) =>
      weeklyReportWeekRange(start.month, start.day, end.month, end.day);

  /// 방금 전 > 분 전 > 시간 전 > 일 전, 7일 넘으면 날짜 (시계가 어긋나 미래여도 방금 전)
  String timeAgoOf(DateTime time, DateTime now) {
    final elapsed = now.difference(time);
    if (elapsed.inMinutes < 1) return timeAgoJustNow;
    if (elapsed.inHours < 1) return timeAgoMinutes(elapsed.inMinutes);
    if (elapsed.inDays < 1) return timeAgoHours(elapsed.inHours);
    if (elapsed.inDays < _maxTimeAgoDays) return timeAgoDays(elapsed.inDays);
    return yearMonthDay(time);
  }
}
