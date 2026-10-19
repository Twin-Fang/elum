import 'package:dio/dio.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/guarded_call.dart';
import '../../../shared/models/routine.dart';

/// 일과관리(보관해 둔 원본) 서버 호출: 목록, 오늘 보내기, 복사, 이름 바꾸기, 지우기
///
/// 모두 [Attempt] 로 돌려준다 — 화면이 실패 팝업과 에러 코드를 띄우고 목록은 그대로 둔다.
class RoutineLibraryApi {
  RoutineLibraryApi(this._dio);

  final Dio _dio;

  static const _repo = 'RoutineLibrary';

  /// 원본 목록 (최신순). 서버가 복제본·숨긴 일과·임시저장을 이미 걸렀다.
  Future<Attempt<List<Routine>>> fetchLibrary() =>
      guarded(_repo, 'fetchLibrary', () async {
        final res = await _dio.get<List<dynamic>>('/api/routines/library');
        return (res.data ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(Routine.fromJson)
            .toList();
      }, describe: (routines) => 'count=${routines.length}');

  /// 오늘 보내기: 원본을 복제해 오늘 일과를 만든다. 오늘 이미 보냈으면 서버가 거절한다.
  Future<Attempt<Routine>> sendToday(String routineId) =>
      _post(routineId, 'send');

  /// 복사하기: 일과관리에 새 원본(`○○ 복사`)을 만든다. 홈에는 나오지 않는다.
  Future<Attempt<Routine>> copy(String routineId) => _post(routineId, 'copy');

  Future<Attempt<Routine>> _post(String routineId, String op) =>
      guarded(_repo, op, () async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/api/routines/$routineId/$op',
        );
        return _routineOf(res.data);
      });

  /// 이름 바꾸기. 제목은 보호자가 쓴 글이라 로그에 남기지 않는다.
  Future<Attempt<Routine>> rename(String routineId, String title) =>
      guarded(_repo, 'rename', () async {
        final res = await _dio.patch<Map<String, dynamic>>(
          '/api/routines/$routineId/title',
          data: {'title': title},
        );
        return _routineOf(res.data);
      });

  /// 일과관리에서 지우기. 수행 기록은 서버가 남긴다.
  Future<AppFailure?> removeFromLibrary(String routineId) async {
    final result = await guarded<void>(
      _repo,
      'removeFromLibrary',
      () => _dio.delete<void>('/api/routines/$routineId/library'),
    );
    return result.failure;
  }

  /// 응답이 비었거나 모양이 다르면 실패로 본다 (빈 화면 대신 다시 시도 안내)
  Routine _routineOf(Map<String, dynamic>? body) {
    if (body == null) throw const AppFailure(fault: NetworkFault.app);
    return Routine.fromJson(body);
  }
}
