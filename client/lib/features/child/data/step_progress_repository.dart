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
/// **절대 throw하지 않고 화면을 기다리게 하지도 않는다.**
/// 아동이 카드를 누르는 순간 체크가 보여야 한다. 네트워크를 기다리면
/// 눌렀는데 반응이 없는 것처럼 느껴진다 (docs/motion.md — 즉각 반응).
class StepProgressRepository {
  StepProgressRepository({Dio? dio}) : _dio = dio ?? DioClient.create();

  final Dio _dio;

  /// 완료 처리 — 별 +1.
  ///
  /// 실패해도 화면은 이미 체크된 상태로 둔다. 아동에게 "안 됐어요"를
  /// 보여줄 방법이 마땅치 않고, 별은 다음 동기화에서 맞출 수 있다.
  Future<void> complete({required String routineId, required String stepId}) {
    return _patch('/api/routines/$routineId/steps/$stepId/complete', '완료');
  }

  /// 완료 취소 — 별 -1.
  ///
  /// ⚠️ 서버는 **가장 마지막에 완료한 단계만** 취소할 수 있다. 순서를 어기면
  /// 409를 준다. 화면은 아무 카드나 해제할 수 있으므로 409가 정상적으로 발생한다.
  /// 그래서 실패를 조용히 흡수한다 — 별 개수는 서버가 진실이고, 화면의 체크는
  /// 아동의 성취감을 위한 것이라 둘이 잠시 어긋나도 괜찮다.
  Future<void> cancel({required String routineId, required String stepId}) {
    return _patch('/api/routines/$routineId/steps/$stepId/cancel', '취소');
  }

  Future<void> _patch(String path, String label) async {
    // 로컬 카드(mock)는 서버에 없다. 보낼 곳이 없으므로 건너뛴다.
    if (AppConfig.useMock) return;

    try {
      await _dio.patch<dynamic>(path);
    } catch (e) {
      // 별 동기화 실패가 아이 화면을 막으면 안 된다 (docs 원칙 6번)
      debugPrint('[star] $label 반영 실패 — 화면은 그대로 진행: $e');
    }
  }
}

final stepProgressRepositoryProvider = Provider<StepProgressRepository>(
  (ref) => StepProgressRepository(dio: ref.watch(dioProvider)),
);
