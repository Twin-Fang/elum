import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';

/// 서버가 완료 집합을 받아들였는가.
///
/// - [accepted]: 반영됨. 대기열에서 빼도 된다.
/// - [rejected]: 서버가 이 상태를 거부했다(승인 전 일과, 삭제된 단계 등). 로컬 기록을
///   버리고 서버 값으로 돌아가야 한다.
/// - [unreachable]: 네트워크·서버 장애. 로컬 기록을 유지하고 다음에 다시 보낸다.
enum SyncOutcome { accepted, rejected, unreachable }

/// 아동 카드 진행 상태를 서버에 반영한다 (이슈 #140).
///
/// 단계별 complete/cancel을 쓰지 않고 **완료 집합을 통째로** `PUT /progress`에 보낸다.
/// 서버가 순서를 검사하지 않고 멱등으로 맞추므로, 오프라인에서 쌓인 변경을 몇 번을
/// 보내도 결과가 같다. 출처: server/.../RoutineControllerDocs.java (syncProgress)
///
/// **절대 throw하지 않는다.** 결과를 [SyncOutcome]으로 돌려주고 판단은 notifier가 한다.
class StepProgressRepository {
  StepProgressRepository({Dio? dio}) : _dio = dio ?? DioClient.create();

  final Dio _dio;

  Future<SyncOutcome> syncProgress({
    required String routineId,
    required Set<String> completedStepIds,
  }) async {
    // 로컬 카드(mock)는 서버에 없다. 보낼 곳이 없으므로 반영된 것으로 본다.
    if (AppConfig.useMock) return SyncOutcome.accepted;

    try {
      await _dio.put<dynamic>(
        '/api/routines/$routineId/progress',
        data: {'completedStepIds': completedStepIds.toList()},
      );
      return SyncOutcome.accepted;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // 4xx 중 서버가 "이 상태는 안 된다"고 답한 것만 거부로 본다.
      // 401은 인터셉터가 토큰을 재발급하므로 여기까지 오면 일시 장애로 취급한다.
      if (status != null && const {400, 403, 404, 409}.contains(status)) {
        debugPrint('[sync] 서버가 진행 상태를 거부함 ($status): $routineId');
        return SyncOutcome.rejected;
      }
      debugPrint('[sync] 서버에 닿지 못함, 다음에 재시도: $routineId ($e)');
      return SyncOutcome.unreachable;
    } catch (e) {
      debugPrint('[sync] 예상 못 한 실패, 다음에 재시도: $routineId ($e)');
      return SyncOutcome.unreachable;
    }
  }
}

final stepProgressRepositoryProvider = Provider<StepProgressRepository>(
  (ref) => StepProgressRepository(dio: ref.watch(dioProvider)),
);
