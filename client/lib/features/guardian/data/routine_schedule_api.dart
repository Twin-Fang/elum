import 'package:dio/dio.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/guarded_call.dart';
import '../domain/routine_schedule.dart';

/// 요일별 반복 일과 서버 호출 (#782, #1080): 주간 계획, 요일·시각 저장, 끄기
///
/// 모두 [Attempt] 로 돌려준다 — 화면이 실패 팝업과 에러 코드를 띄우고 보이던 값은 그대로 둔다.
class RoutineScheduleApi {
  RoutineScheduleApi(this._dio);

  final Dio _dio;

  static const _repositoryName = 'RoutineSchedule';
  static const _path = '/api/routine-schedules';

  Future<Attempt<RoutineSchedulePlan>> fetchPlan() =>
      guarded(_repositoryName, 'fetchPlan', () async {
        final response = await _dio.get<Map<String, dynamic>>(_path);
        return RoutineSchedulePlan.fromJson(response.data);
      }, describe: (plan) => 'count=${plan.schedules.length}');

  /// 저장 (같은 일과면 덮어씀). Free 면 서버가 ROUTINE_SCHEDULE_NOT_ALLOWED 로 거절한다
  Future<AppFailure?> save(RoutineSchedule schedule) async {
    final saveAttempt = await guarded<void>(
      _repositoryName,
      'save',
      () => _dio.put<void>(
        '$_path/${schedule.routineId}',
        data: {
          'weekdays': schedule.weekdayWires,
          'time': schedule.timeWire,
          'notifyEnabled': schedule.isNotifyEnabled,
        },
      ),
    );
    return saveAttempt.failure;
  }

  /// 끄기 (요금제와 무관)
  Future<AppFailure?> delete(String routineId) async {
    final deleteAttempt = await guarded<void>(
      _repositoryName,
      'delete',
      () => _dio.delete<void>('$_path/$routineId'),
    );
    return deleteAttempt.failure;
  }
}
