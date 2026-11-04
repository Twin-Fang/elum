import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dio_provider.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/guarded_call.dart';
import '../domain/routine_memory.dart';

/// 이룸이별 AI 메모 API (`/api/routine-memory`). 고른 이룸이는 `X-Profile-Id` 로 실린다.
/// 메모 줄은 보호자가 쓴 글이라 로그에 남기지 않는다 (요약만). 실패는 [AppFailure] 로 던진다.
class RoutineMemoryRepository {
  RoutineMemoryRepository(this._dio);

  final Dio _dio;

  static const _path = '/api/routine-memory';

  Future<RoutineMemory> fetch() => _call('fetch', () async {
        final response = await _dio.get<Map<String, dynamic>>(_path);
        return RoutineMemory.fromJson(_bodyOf(response));
      });

  /// 화면에 보이는 줄 전체를 그대로 저장 > 서버가 저장한 메모
  Future<RoutineMemory> replaceLines(List<String> lines) => _call('replaceLines', () async {
        final response = await _dio.put<Map<String, dynamic>>('$_path/lines', data: {'lines': lines});
        return RoutineMemory.fromJson(_bodyOf(response));
      });

  Future<RoutineMemory> setEnabled(bool isEnabled) => _call('setEnabled', () async {
        final response = await _dio.patch<Map<String, dynamic>>('$_path/enabled', data: {'enabled': isEnabled});
        return RoutineMemory.fromJson(_bodyOf(response));
      });

  /// 모두 지우기 (지난 일과에서 배운 것도 함께)
  Future<RoutineMemory> clear() => _call('clear', () async {
        final response = await _dio.delete<Map<String, dynamic>>(_path);
        return RoutineMemory.fromJson(_bodyOf(response));
      });

  /// 로그(줄 수만) + 모든 실패를 [AppFailure] 로 통일
  Future<RoutineMemory> _call(String operation, Future<RoutineMemory> Function() body) async {
    try {
      return await logged('RoutineMemoryRepository', operation, body,
          describe: (memory) => 'lines=${memory.lines.length}, enabled=${memory.isEnabled}');
    } catch (e) {
      throw AppFailure.of(e);
    }
  }

  Map<String, dynamic> _bodyOf(Response<Map<String, dynamic>> response) {
    final body = response.data;
    if (body == null) throw const FormatException('empty response');
    return body;
  }
}

final routineMemoryRepositoryProvider = Provider<RoutineMemoryRepository>(
  (ref) => RoutineMemoryRepository(ref.watch(dioProvider)),
);
