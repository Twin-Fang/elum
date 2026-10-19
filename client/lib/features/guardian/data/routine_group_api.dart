import 'package:dio/dio.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/guarded_call.dart';
import '../../../shared/models/routine.dart';
import '../domain/routine_group.dart';

/// 일과 묶음(폴더) 서버 호출 (#806): 목록, 만들기, 이름, 구성·순서, 풀기, 복사, 묶음째 보내기
///
/// 모두 [Attempt] 로 돌려준다 — 화면이 실패 팝업과 에러 코드를 띄우고 격자는 그대로 둔다.
class RoutineGroupApi {
  RoutineGroupApi(this._dio);

  final Dio _dio;

  static const _repositoryName = 'RoutineGroup';
  static const _path = '/api/routine-groups';

  Future<Attempt<List<RoutineGroup>>> fetchGroups() =>
      guarded(_repositoryName, 'fetchGroups', () async {
        final response = await _dio.get<List<dynamic>>(_path);
        return [
          for (final json in response.data ?? const <dynamic>[])
            ?RoutineGroup.tryFromJson(json),
        ];
      }, describe: (groups) => 'count=${groups.length}');

  /// 묶음 만들기. [routineIds] 순서가 묶음 순서다 (2개 이상). 이름은 보호자가 쓴 글이라 로그에 남기지 않는다
  Future<Attempt<RoutineGroup>> create(String name, List<String> routineIds) =>
      _group(
        'create',
        () => _dio.post<Map<String, dynamic>>(
          _path,
          data: {'name': name, 'routineIds': routineIds},
        ),
      );

  Future<Attempt<RoutineGroup>> rename(String groupId, String name) => _group(
    'rename',
    () => _dio.patch<Map<String, dynamic>>(
      '$_path/$groupId/name',
      data: {'name': name},
    ),
  );

  /// 구성과 순서를 통째로 바꾼다 (넣기·빼기·순서 바꾸기 공통). 1개가 남으면 [ungroup] 을 부른다
  Future<Attempt<RoutineGroup>> replaceRoutines(
    String groupId,
    List<String> routineIds,
  ) => _group(
    'replaceRoutines',
    () => _dio.put<Map<String, dynamic>>(
      '$_path/$groupId/routines',
      data: {'routineIds': routineIds},
    ),
  );

  Future<Attempt<RoutineGroup>> copy(String groupId) => _group(
    'copy',
    () => _dio.post<Map<String, dynamic>>('$_path/$groupId/copy'),
  );

  /// 묶음 풀기. 안의 일과는 일과관리에 그대로 남는다
  Future<AppFailure?> ungroup(String groupId) async {
    final ungroupAttempt = await guarded<void>(
      _repositoryName,
      'ungroup',
      () => _dio.delete<void>('$_path/$groupId'),
    );
    return ungroupAttempt.failure;
  }

  /// 묶음째 오늘 보내기 > 만들어진 오늘 일과 (이미 오늘 보낸 일과는 서버가 건너뛴다)
  Future<Attempt<List<Routine>>> sendToday(String groupId) =>
      guarded(_repositoryName, 'sendToday', () async {
        final response = await _dio.post<List<dynamic>>('$_path/$groupId/send');
        return (response.data ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(Routine.fromJson)
            .toList();
      }, describe: (routines) => 'sent=${routines.length}');

  Future<Attempt<RoutineGroup>> _group(
    String op,
    Future<Response<Map<String, dynamic>>> Function() call,
  ) => guarded(_repositoryName, op, () async {
    final group = RoutineGroup.tryFromJson((await call()).data);
    // 응답이 비었거나 모양이 다르면 실패로 본다 (빈 묶음을 그리지 않는다)
    if (group == null) throw const AppFailure(fault: NetworkFault.app);
    return group;
  });
}
