import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';

/// 카드 완료·취소를 서버에 반영한다. 별 지급이 여기서 일어난다.
///
/// 서버는 완료 시 보호자의 누적 별(`totalStars`)을 1 올리고, 취소 시 1 내린다.
/// 출처: server/.../RoutineControllerDocs.java
///
/// **절대 throw하지 않고 화면을 기다리게 하지도 않는다.** 대신 **성공 여부를 돌려준다.**
/// 예전엔 실패를 여기서 삼켰는데, 그러면 화면은 체크됐고 서버엔 없는 상태가 생겨
/// 앱을 다시 열면 진행률이 되돌아갔다 (이슈 #139). 되돌릴지는 호출부(notifier)가 정한다.
class StepProgressRepository {
  StepProgressRepository({Dio? dio}) : _dio = dio ?? DioClient.create();

  final Dio _dio;

  /// 완료 처리 — 별 +1. 서버가 받아들였으면 true.
  ///
  /// 서버는 **이전 단계가 미완료면 409**를 준다 (`RoutineService.completeStep`).
  Future<bool> complete({required String routineId, required String stepId}) {
    return _patch('/api/routines/$routineId/steps/$stepId/complete', '완료');
  }

  /// 완료 취소 — 별 -1. 서버가 받아들였으면 true.
  ///
  /// 서버는 **가장 마지막에 완료한 단계만** 취소를 허용하고, 순서를 어기면 409를 준다.
  Future<bool> cancel({required String routineId, required String stepId}) {
    return _patch('/api/routines/$routineId/steps/$stepId/cancel', '취소');
  }

  Future<bool> _patch(String path, String label) async {
    // 로컬 카드(mock)는 서버에 없다. 보낼 곳이 없으므로 성공으로 본다.
    if (AppConfig.useMock) return true;

    try {
      await _dio.patch<dynamic>(path);
      return true;
    } catch (e) {
      // 화면을 막지는 않는다 (docs 원칙 6번). 되돌림은 notifier가 한다.
      debugPrint('[star] $label 반영 실패: $e');
      return false;
    }
  }
}

final stepProgressRepositoryProvider = Provider<StepProgressRepository>(
  (ref) => StepProgressRepository(dio: ref.watch(dioProvider)),
);
