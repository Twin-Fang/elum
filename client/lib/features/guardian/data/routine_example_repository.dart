import 'package:dio/dio.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/network/app_failure.dart';
import '../../../shared/models/routine.dart';

/// 온보딩 예시 일과 API (#803): 고른 분류 코드 > 서버가 만든 예시 일과 목록
///
/// 일과 저장소([RoutineRepository])와 따로 둔다 — 그쪽은 테스트 대역이 많아 메서드 하나 추가가 수십 곳을 바꾼다.
class RoutineExampleRepository {
  RoutineExampleRepository(this._dio);

  final Dio _dio;

  /// 예시 일과 생성. 이미 만든 이룸이면 서버가 빈 목록을 준다 (성공)
  Future<Attempt<List<Routine>>> createExamples(
    List<String> categoryCodes,
  ) async {
    AppLogger.repositoryCall('RoutineExampleRepository', 'createExamples', {
      'categories': categoryCodes,
    });
    try {
      final response = await _dio.post<List<dynamic>>(
        '/api/routines/examples',
        data: {'categories': categoryCodes},
      );
      final routines = (response.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Routine.fromJson)
          .toList();
      AppLogger.repositorySuccess(
        'RoutineExampleRepository',
        'createExamples',
        'examples ${routines.length}',
      );
      return Attempt.ok(routines);
    } catch (e) {
      // 호출부(홈)가 재시도 여부를 정하고 스낵바로 알린다
      AppLogger.repositoryError(
        'RoutineExampleRepository',
        'createExamples',
        e,
      );
      return Attempt.failed(AppFailure.of(e));
    }
  }
}
