import 'package:dio/dio.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/network/app_failure.dart';
import '../domain/weekly_report.dart';
import '../domain/weekly_report_weeks.dart';

/// 주간 리포트 API (#1074): 그 주 월요일 > 한 주 요약 (이룸이는 `X-Profile-Id` 헤더가 정함)
class WeeklyReportRepository {
  WeeklyReportRepository(this._dio);

  final Dio _dio;

  static const _path = '/api/routines/weekly-report';

  /// 한 주 요약. Free 는 서버가 403 `WEEKLY_REPORT_NOT_ALLOWED` (실패로 돌려줌)
  Future<Attempt<WeeklyReport>> fetchWeeklyReport(DateTime weekStart) async {
    final weekStartText = _toIsoDate(weekStart);
    AppLogger.repositoryCall('WeeklyReportRepository', 'fetchWeeklyReport', {'weekStart': weekStartText});
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _path,
        queryParameters: {'weekStart': weekStartText},
      );
      final body = response.data;
      if (body == null) throw const FormatException('weekly report empty body');
      final report = WeeklyReport.fromJson(body);
      AppLogger.repositorySuccess(
        'WeeklyReportRepository',
        'fetchWeeklyReport',
        'sent ${report.sentRoutineCount}',
      );
      return Attempt.ok(report);
    } catch (error) {
      // 화면이 에러 코드와 다시 하기를 그린다
      AppLogger.repositoryError('WeeklyReportRepository', 'fetchWeeklyReport', error);
      return Attempt.failed(AppFailure.of(error));
    }
  }

  /// 지난 리포트 주 목록 (최신순) + Free 미리 보기 주. 권한이 없어도 부를 수 있음
  Future<Attempt<WeeklyReportWeeks>> fetchWeeks() async {
    AppLogger.repositoryCall('WeeklyReportRepository', 'fetchWeeks', null);
    try {
      final response = await _dio.get<Map<String, dynamic>>('$_path/weeks');
      final body = response.data;
      if (body == null) throw const FormatException('weekly report weeks empty body');
      final weeks = WeeklyReportWeeks.fromJson(body);
      AppLogger.repositorySuccess('WeeklyReportRepository', 'fetchWeeks', 'weeks ${weeks.weeks.length}');
      return Attempt.ok(weeks);
    } catch (error) {
      AppLogger.repositoryError('WeeklyReportRepository', 'fetchWeeks', error);
      return Attempt.failed(AppFailure.of(error));
    }
  }

  /// 날짜 > `yyyy-MM-dd`
  static String _toIsoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
