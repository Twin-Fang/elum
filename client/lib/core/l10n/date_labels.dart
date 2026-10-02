import '../../l10n/app_localizations.dart';

/// `DateTime.weekday`(1=월 … 7=일) → ARB `select` 키.
const _weekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// 날짜·요일 문구. 순서·단위·요일 이름은 언어마다 ARB 가 정한다 — 코드가 `월`·`일` 을 붙이지 않는다.
extension DateLabels on AppLocalizations {
  /// `월` 같은 짧은 요일.
  String weekdayShortOf(DateTime d) => weekdayShort(_weekdayKeys[d.weekday - 1]);

  /// `2026년 9월 20일`
  String yearMonthDay(DateTime d) => dateYearMonthDay(d.year, d.month, d.day);

  /// `9월 18일부터`
  String monthDaySince(DateTime d) => dateMonthDaySince(d.month, d.day);

  /// `9월 28일(월) 0시` — 분이 0이면 분을 적지 않는다.
  String resetAt(DateTime d) => d.minute == 0
      ? creditResetAt(d.month, d.day, weekdayShortOf(d), d.hour)
      : creditResetAtMinute(d.month, d.day, weekdayShortOf(d), d.hour, d.minute);
}
