import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dio_provider.dart';
import '../../profile/application/profile_session.dart';
import '../data/weekly_report_repository.dart';
import '../domain/weekly_report.dart';

final weeklyReportRepositoryProvider = Provider<WeeklyReportRepository>(
  (ref) => WeeklyReportRepository(ref.watch(dioProvider)),
);

/// 한 주 요약 (주 월요일별). 실패면 [AppFailure] 를 던져 화면이 에러 코드·다시 하기를 그린다
///
/// 고른 이룸이가 바뀌면 다시 받는다 (요청 헤더 `X-Profile-Id` 가 바뀜).
final weeklyReportProvider = FutureProvider.autoDispose.family<WeeklyReport, DateTime>((
  ref,
  weekStart,
) async {
  ref.watch(profileSessionProvider.select((session) => session.selectedId));
  final attempt = await ref.watch(weeklyReportRepositoryProvider).fetchWeeklyReport(weekStart);
  final failure = attempt.failure;
  if (failure != null) throw failure;
  final report = attempt.value;
  if (report == null) throw StateError('weekly report missing value');
  return report;
});

/// 보고 있는 주 (월요일 0시). 화면을 다시 열면 이번 주부터
class WeeklyReportWeekNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => weekStartOf(DateTime.now());

  bool get canShowNextWeek => state.isBefore(weekStartOf(DateTime.now()));

  void showPreviousWeek() => state = _shifted(-1);

  /// 이번 주보다 뒤로는 가지 않음 (서버도 400)
  void showNextWeek() {
    if (canShowNextWeek) state = _shifted(1);
  }

  // 일광 절약 시각이 있는 기기에서도 날짜가 밀리지 않게 날짜 단위로 계산
  DateTime _shifted(int weeks) => DateTime(state.year, state.month, state.day + weeks * DateTime.daysPerWeek);
}

final weeklyReportWeekProvider = NotifierProvider.autoDispose<WeeklyReportWeekNotifier, DateTime>(
  WeeklyReportWeekNotifier.new,
);
