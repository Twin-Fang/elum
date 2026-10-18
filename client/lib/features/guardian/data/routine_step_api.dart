import 'package:dio/dio.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/network/app_failure.dart';
import '../../../shared/models/action_card.dart';
import '../../../shared/models/routine.dart';

/// 일과 카드 서버 호출: 추가, 수정, 순서 변경, 삭제
/// 서버에 없는 로컬 일과(id 비어 있음)는 호출 없이 로컬 결과를 돌려줌
class RoutineStepApi {
  RoutineStepApi(this._dio);

  final Dio _dio;

  Future<({Routine routine, AppFailure? failure})> addStep(
    Routine routine, {
    required String title,
    required String description,
  }) async {
    // 제목·설명은 보호자가 쓴 글이라 로그에 남기지 않는다 (docs 원칙 5번)
    AppLogger.repositoryCall('RoutineRepository', 'addStep', {
      'routineId': routine.id,
    });

    // 서버에 없는 로컬 일과 — 데모가 끝까지 가도록 로컬에 넣는다
    if (routine.id.isEmpty) {
      final added = ActionCard(
        id: 'local_${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        description: description,
        stepOrder: routine.steps.length + 1,
      );
      return (
        routine: routine.copyWith(steps: [...routine.steps, added]),
        failure: null,
      );
    }

    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/routines/${routine.id}/steps',
        data: {'title': title, 'description': description},
      );
      final body = res.data;
      if (body == null) {
        return (
          routine: routine,
          failure: const AppFailure(fault: NetworkFault.app),
        );
      }
      AppLogger.repositorySuccess('RoutineRepository', 'addStep', '카드 추가 완료');
      return (routine: Routine.fromJson(body), failure: null);
    } catch (e) {
      AppLogger.repositoryError('RoutineRepository', 'addStep', e);
      return (routine: routine, failure: AppFailure.of(e));
    }
  }

  Future<({Routine routine, AppFailure? failure})> updateStep(
    Routine routine,
    String stepId, {
    required String title,
    required String description,
  }) async {
    // 보호자가 고친 글은 글자 수만 (docs 원칙 5번)
    AppLogger.repositoryCall('RoutineRepository', 'updateStep', {
      'routineId': routine.id,
      'stepId': stepId,
      'titleLength': title.length,
      'descriptionLength': description.length,
    });

    // 서버로 보내려 했는데 왜 실패했는가 — **이유까지 들고 나간다.**
    // `false` 로 납작하게 만들면 서버가 알려준 문구가 여기서 사라진다.
    AppFailure? failure;

    if (routine.id.isNotEmpty) {
      try {
        final res = await _dio.patch<Map<String, dynamic>>(
          '/api/routines/${routine.id}/steps/$stepId',
          // 보낸 필드만 바뀐다 — 제목도 함께 보내야 서버에 남는다
          data: {'title': title, 'description': description},
        );
        final body = res.data;
        if (body != null) {
          final updated = Routine.fromJson(body);
          AppLogger.repositorySuccess(
            'RoutineRepository',
            'updateStep',
            '카드 내용 수정 완료',
          );
          return (routine: updated, failure: null);
        }
        failure = const AppFailure(fault: NetworkFault.app);
      } catch (e) {
        AppLogger.repositoryError('RoutineRepository', 'updateStep', e);
        failure = AppFailure.of(e);
      }
    }

    final updated = routine.copyWith(
      steps: [
        for (final step in routine.steps)
          if (step.id == stepId)
            // 글이 바뀌면 옛 음성 열쇠도 버린다 (서버에 못 올렸어도 옛 문장이 읽히지 않게, #675)
            step.copyWith(
              title: title,
              description: description,
              speechPath: null,
            )
          else
            step,
      ],
    );
    AppLogger.repositorySuccess(
      'RoutineRepository',
      'updateStep (로컬)',
      '로컬에서 카드 내용 수정됨',
    );
    return (routine: updated, failure: failure);
  }

  Future<AppFailure?> reorderSteps(
    String routineId,
    List<String> stepIds,
  ) async {
    AppLogger.repositoryCall('RoutineRepository', 'reorderSteps', {
      'routineId': routineId,
      'count': stepIds.length,
    });

    if (routineId.isEmpty || stepIds.isEmpty) return null;

    try {
      await _dio.patch<void>(
        '/api/routines/$routineId/steps/order',
        data: {'stepIds': stepIds},
      );
      AppLogger.repositorySuccess(
        'RoutineRepository',
        'reorderSteps',
        '단계 순서 저장됨',
      );
      return null;
    } catch (e) {
      // 일과 순서와 같다 — 실패를 삼키지 않고 부르는 쪽이 화면을 되돌린다.
      AppLogger.repositoryError('RoutineRepository', 'reorderSteps', e);
      return AppFailure.of(e);
    }
  }

  Future<AppFailure?> deleteStep(String routineId, String stepId) async {
    AppLogger.repositoryCall('RoutineRepository', 'deleteStep', {
      'routineId': routineId,
      'stepId': stepId,
    });

    if (routineId.isEmpty || stepId.isEmpty) {
      return const AppFailure(fault: NetworkFault.app);
    }

    try {
      // 응답으로 일과 전체가 오지만 쓰지 않는다 — 로컬 카드 상태를 그대로 둔다.
      await _dio.delete<void>('/api/routines/$routineId/steps/$stepId');
      AppLogger.repositorySuccess('RoutineRepository', 'deleteStep', '카드 빠짐');
      return null;
    } catch (e) {
      AppLogger.repositoryError('RoutineRepository', 'deleteStep', e);
      return AppFailure.of(e);
    }
  }
}
