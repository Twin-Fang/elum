import 'package:dio/dio.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/models/routine.dart';
import '../../../shared/models/support_goal.dart';
import '../../credit/domain/credit_summary.dart';
import '../domain/routine_suggestion.dart';
import 'routine_repository.dart';
import 'routine_step_api.dart';
import 'today_routine_cache.dart';

class RoutineRepositoryImpl implements RoutineRepository {
  RoutineRepositoryImpl({Dio? dio, LocalStorage? storage})
    : _dio = dio ?? DioClient.create(),
      _storage = storage;

  final Dio _dio;

  /// 오늘 일과 캐시용. null이면 캐시 없이 동작한다(기존 테스트 호환).
  final LocalStorage? _storage;

  late final _stepApi = RoutineStepApi(_dio);
  late final _todayCache = TodayRoutineCache(_storage);

  @override
  Future<List<Routine>> getMyRoutines() async {
    AppLogger.repositoryCall('RoutineRepository', 'getMyRoutines');

    try {
      final res = await _dio.get<List<dynamic>>('/api/routines');
      final body = res.data;
      if (body == null) return const [];

      final routines = body
          .whereType<Map<String, dynamic>>()
          .map(Routine.fromJson)
          .toList();

      AppLogger.repositorySuccess(
        'RoutineRepository',
        'getMyRoutines',
        '${routines.length}개 일과 조회됨',
      );
      return routines;
    } catch (e) {
      // 빈 목록으로 뭉개지 않는다 — "아직 만든 게 없다"와 "불러오지 못했다"가
      // 같은 화면이 되면 보호자도 우리도 무엇이 잘못됐는지 알 수 없다.
      AppLogger.repositoryError('RoutineRepository', 'getMyRoutines', e);
      rethrow;
    }
  }

  @override
  Future<List<RoutineSuggestion>> getSuggestions() async {
    AppLogger.repositoryCall('RoutineRepository', 'getSuggestions');

    try {
      final res = await _dio.get<List<dynamic>>('/api/routines/suggestions');
      final body = res.data;

      final parsed =
          body
              ?.whereType<Map<String, dynamic>>()
              .map(RoutineSuggestion.fromJson)
              .where((s) => s.text.isNotEmpty)
              .toList() ??
          const <RoutineSuggestion>[];

      final result = parsed.isEmpty ? RoutineSuggestion.fallback : parsed;
      AppLogger.repositorySuccess(
        'RoutineRepository',
        'getSuggestions',
        '${result.length}개 추천 조회됨',
      );
      return result;
    } catch (e) {
      // 내장 추천으로 대신하지 않는다. 추천이 안 뜨는 것보다
      // 왜 안 뜨는지 모르는 것이 나쁘다.
      AppLogger.repositoryError('RoutineRepository', 'getSuggestions', e);
      rethrow;
    }
  }

  @override
  Future<RoutineQuestion> generateQuestion(String rawInputText) async {
    // 보호자 원문은 남기지 않고 글자 수만 (docs 원칙 5번)
    AppLogger.repositoryCall('RoutineRepository', 'generateQuestion', {
      'rawInputLength': rawInputText.length,
    });

    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/routines/questions',
        data: {'rawInputText': rawInputText},
      );
      final body = res.data;
      if (body != null) {
        final question = RoutineQuestion.fromJson(body);
        AppLogger.repositorySuccess(
          'RoutineRepository',
          'generateQuestion',
          question,
        );
        return question;
      }
    } catch (e) {
      AppLogger.repositoryError('RoutineRepository', 'generateQuestion', e);
      // 서버에 닿지 못했다 — 흐름이 연결 안내를 띄우게 넘긴다.
      final failure = AppFailure.of(e);
      if (failure.isUnreachable) throw failure;
      // 크레딧이 막았다. 질문 없이 넘기면 카드 만들기에서 같은 이유로 또
      // 막힌다 — 질문 단계에서 멈추고 `홈으로` 오류 화면을 띄우게 넘긴다.
      if (isCreditBlockingCode(failure.badgeOr(''))) throw failure;
    }

    // 응답은 받았는데 실패했다(5xx·빈 본문 등). 입력과 무관한 대체 질문은
    // 엉뚱한 질문(수영장 가기에 우산)이 되므로 주지 않는다.
    // 질문은 선택 단계라 없이 넘어가도 카드는 만들어진다.
    AppLogger.repositorySuccess(
      'RoutineRepository',
      'generateQuestion (질문 없이 넘어감)',
      const RoutineQuestion(),
    );
    return const RoutineQuestion();
  }

  @override
  Future<Routine> createRoutine({
    required String rawInputText,
    required Set<SupportGoal> goals,
    List<String> answers = const [],
    String rewardText = '',
    String rewardPresetKey = '',
    String idempotencyKey = '',
  }) async {
    // 원문·답은 글자 수·개수만 (docs 원칙 5번)
    AppLogger.repositoryCall('RoutineRepository', 'createRoutine', {
      'rawInputLength': rawInputText.length,
      'goals': goals.map((g) => g.apiValue).toList(),
      'answerCount': answers.length,
      // 보상 내용은 보호자가 적은 자유 문구라 로그에 남기지 않는다 (docs 원칙 5번).
      'hasReward': rewardText.trim().isNotEmpty,
    });

    final res = await _dio.post<Map<String, dynamic>>(
      '/api/routines',
      data: {
        'rawInputText': rawInputText,
        // 서버 getTodayRoutines는 scheduledAt이 '오늘(KST)' 범위인 일과만 아이 홈에 노출한다.
        // +1일(내일)로 저장하면 승인해도 오늘 목록에서 빠져 아이 모드가 항상 비어 보인다 → now로 저장.
        'scheduledAt': DateTime.now().toIso8601String().split('.').first,
        'answers': answers,
        // 보상은 선택 항목이다. 비어 있으면 키를 아예 보내지 않는다 —
        // 빈 문자열을 보내면 서버가 "보상 없음"이 아니라 "빈 보상"으로 저장한다.
        if (rewardText.trim().isNotEmpty) 'rewardText': rewardText.trim(),
        if (rewardPresetKey.trim().isNotEmpty)
          'rewardPresetKey': rewardPresetKey.trim(),
      },
      options: idempotencyKey.isEmpty
          ? null
          : Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    final body = res.data;
    // 응답이 비었거나 카드가 0장이면 실패로 본다. 로컬로 지어내지 않고 예외를 던져
    // notifier가 에러 화면(코드+재시도)으로 처리하게 한다. 재시도는 AI를 다시 호출한다.
    if (body == null) {
      AppLogger.repositoryError('RoutineRepository', 'createRoutine', '빈 응답');
      throw StateError('카드 생성 응답이 비었습니다');
    }
    final routine = Routine.fromJson(body);
    if (routine.steps.isEmpty) {
      AppLogger.repositoryError(
        'RoutineRepository',
        'createRoutine',
        '카드 0장 수신',
      );
      throw StateError('생성된 카드가 없습니다');
    }
    AppLogger.repositorySuccess(
      'RoutineRepository',
      'createRoutine',
      '${routine.steps.length}개 카드 생성됨',
    );
    return routine;
  }

  @override
  Future<Routine> confirm(Routine routine) async {
    AppLogger.repositoryCall('RoutineRepository', 'confirm', {
      'routineId': routine.id,
    });

    // 승인은 **서버에 반영돼야 뜻이 있다.** 이룸이 화면에 카드를 노출할지를
    // 정하는 동작이라(docs 원칙 3번), 로컬만 CONFIRMED로 바꿔 두면 보호자는
    // 승인했다고 믿는데 이룸이 휴대폰에는 아무것도 뜨지 않는다.
    // 그때 보호자가 의심할 곳은 앱이 아니라 이룸이다.
    if (routine.id.isEmpty) {
      AppLogger.repositoryError(
        'RoutineRepository',
        'confirm',
        '서버에 저장되지 않은 일과는 승인할 수 없다',
      );
      throw StateError('승인할 일과가 서버에 없습니다');
    }

    final res = await _dio.patch<Map<String, dynamic>>(
      '/api/routines/${routine.id}/confirm',
    );
    final body = res.data;
    if (body == null) {
      throw StateError('승인 응답이 비어 있습니다');
    }

    final confirmed = Routine.fromJson(body);
    AppLogger.repositorySuccess('RoutineRepository', 'confirm', '일과 승인 완료');
    return confirmed;
  }

  @override
  Future<({Routine routine, AppFailure? failure})> addStep(
    Routine routine, {
    required String title,
    required String description,
  }) => _stepApi.addStep(routine, title: title, description: description);

  @override
  Future<({Routine routine, AppFailure? failure})> updateStep(
    Routine routine,
    String stepId, {
    required String title,
    required String description,
  }) => _stepApi.updateStep(
    routine,
    stepId,
    title: title,
    description: description,
  );

  @override
  Future<AppFailure?> reorderSteps(String routineId, List<String> stepIds) =>
      _stepApi.reorderSteps(routineId, stepIds);

  @override
  Future<AppFailure?> deleteStep(String routineId, String stepId) =>
      _stepApi.deleteStep(routineId, stepId);

  @override
  Future<List<Routine>> getTodayRoutines() async {
    AppLogger.repositoryCall('RoutineRepository', 'getTodayRoutines');

    try {
      final res = await _dio.get<List<dynamic>>('/api/routines/today');
      final body = res.data;
      if (body != null) {
        final routines = body
            .whereType<Map<String, dynamic>>()
            .map(Routine.fromJson)
            .toList();
        AppLogger.repositorySuccess(
          'RoutineRepository',
          'getTodayRoutines',
          '${routines.length}개 오늘 일과 조회됨',
        );
        // 성공한 응답을 캐시해 둔다 — 다음에 오프라인이면 이걸 보여준다.
        // toJson 이 보호자 원문을 빼고 직렬화한다.
        await _todayCache.save(routines);
        return routines;
      }
    } catch (e) {
      AppLogger.repositoryError('RoutineRepository', 'getTodayRoutines', e);
    }

    // 오프라인이거나 서버가 죽었다 — 마지막 성공 응답이 있으면 그걸 쓴다.
    final cached = _todayCache.read();
    if (cached != null) {
      AppLogger.repositorySuccess(
        'RoutineRepository',
        'getTodayRoutines (캐시)',
        '${cached.length}개 오프라인 캐시 사용',
      );
      return _todayCache.onlyToday(cached);
    }

    // 캐시도 없으면 전체 조회로 폴백. 전체에는 어제 것·승인 전 것이 섞여 있어 오늘 것만
    // 남긴다 — 거르지 않으면 보호자 홈 오늘 일과에 그대로 뜬다 (docs 원칙 3번).
    AppLogger.repositorySuccess(
      'RoutineRepository',
      'getTodayRoutines (폴백)',
      '전체 일과 조회로 대체',
    );
    return _todayCache.onlyToday(await getMyRoutines());
  }

  // --- 보상(강화물) · 일과 정리 ---

  @override
  Future<({Routine routine, AppFailure? failure})> updateReward(
    Routine routine, {
    required String rewardText,
    String rewardPresetKey = '',
  }) async {
    final trimmed = rewardText.trim();
    AppLogger.repositoryCall('RoutineRepository', 'updateReward', {
      'routineId': routine.id,
      // 보상 문구 자체는 남기지 않는다 (docs 원칙 5번).
      'hasReward': trimmed.isNotEmpty,
      'preset': rewardPresetKey,
    });

    AppFailure? failure;

    if (routine.id.isNotEmpty) {
      try {
        final res = await _dio.patch<Map<String, dynamic>>(
          '/api/routines/${routine.id}/reward',
          data: {
            // 빈 문자열을 그대로 보낸다 — 서버가 이걸 "보상 지우기"로 읽는다.
            'rewardText': trimmed,
            'rewardPresetKey': rewardPresetKey.trim(),
          },
        );
        final body = res.data;
        if (body != null) {
          AppLogger.repositorySuccess(
            'RoutineRepository',
            'updateReward',
            trimmed.isEmpty ? '보상 삭제됨' : '보상 저장됨',
          );
          return (routine: Routine.fromJson(body), failure: null);
        }
        failure = const AppFailure(fault: NetworkFault.app);
      } catch (e) {
        AppLogger.repositoryError('RoutineRepository', 'updateReward', e);
        failure = AppFailure.of(e);
      }
    }

    // 서버에 못 보냈어도 화면에는 반영한다. 보호자가 방금 고른 값이 사라지면
    // 저장이 안 된 건지 잘못 고른 건지 알 수 없다.
    final updated = routine.copyWith(
      rewardText: trimmed,
      rewardPresetKey: rewardPresetKey.trim(),
    );
    return (routine: updated, failure: failure);
  }

  @override
  Future<List<RecentReward>> getRecentRewards() async {
    AppLogger.repositoryCall('RoutineRepository', 'getRecentRewards');

    try {
      final res = await _dio.get<List<dynamic>>('/api/routines/recent-rewards');
      final rewards =
          res.data
              ?.whereType<Map<String, dynamic>>()
              .map(RecentReward.fromJson)
              .where((r) => r.isValid)
              .toList() ??
          const <RecentReward>[];
      AppLogger.repositorySuccess(
        'RoutineRepository',
        'getRecentRewards',
        '${rewards.length}개 최근 보상',
      );
      return rewards;
    } catch (e) {
      // 실패해도 보상 설정 자체는 할 수 있어야 한다 — 재사용 칩은 편의 기능이다.
      AppLogger.repositoryError('RoutineRepository', 'getRecentRewards', e);
      return const [];
    }
  }

  @override
  Future<List<Routine>> getPastRoutines() =>
      _fetchRoutineList('/api/routines/past', 'getPastRoutines');

  @override
  Future<List<Routine>> getDraftRoutines() =>
      _fetchRoutineList('/api/routines/drafts', 'getDraftRoutines');

  /// 목록 조회 3종이 같은 모양이라 한 곳에 모았다.
  /// **실패하면 빈 목록이다.** 홈 화면의 한 구역이 비는 것뿐이라 화면은 살아 있다.
  Future<List<Routine>> _fetchRoutineList(String path, String label) async {
    AppLogger.repositoryCall('RoutineRepository', label);

    try {
      final res = await _dio.get<List<dynamic>>(path);
      final routines =
          res.data
              ?.whereType<Map<String, dynamic>>()
              .map(Routine.fromJson)
              .toList() ??
          const <Routine>[];
      AppLogger.repositorySuccess(
        'RoutineRepository',
        label,
        '${routines.length}개 조회됨',
      );
      return routines;
    } catch (e) {
      AppLogger.repositoryError('RoutineRepository', label, e);
      rethrow;
    }
  }

  @override
  Future<Attempt<Routine>> duplicate(String routineId) async {
    AppLogger.repositoryCall('RoutineRepository', 'duplicate', {
      'routineId': routineId,
    });

    if (routineId.isEmpty) {
      return const Attempt.failed(AppFailure(fault: NetworkFault.app));
    }

    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/routines/$routineId/duplicate',
      );
      final body = res.data;
      if (body == null) {
        return const Attempt.failed(AppFailure(fault: NetworkFault.app));
      }
      AppLogger.repositorySuccess(
        'RoutineRepository',
        'duplicate',
        '오늘 일과로 복제됨',
      );
      return Attempt.ok(Routine.fromJson(body));
    } catch (e) {
      // 화면이 토스트로 알리고 목록은 그대로 둔다.
      AppLogger.repositoryError('RoutineRepository', 'duplicate', e);
      return Attempt.failed(AppFailure.of(e));
    }
  }

  @override
  Future<AppFailure?> reorder(List<String> routineIds) async {
    AppLogger.repositoryCall('RoutineRepository', 'reorder', {
      'count': routineIds.length,
    });

    if (routineIds.isEmpty) return null;

    try {
      await _dio.patch<void>(
        '/api/routines/order',
        data: {'routineIds': routineIds},
      );
      AppLogger.repositorySuccess('RoutineRepository', 'reorder', '순서 저장됨');
      return null;
    } catch (e) {
      // 실패를 삼키지 않는다 — 부르는 쪽이 목록을 되돌려야 한다.
      AppLogger.repositoryError('RoutineRepository', 'reorder', e);
      return AppFailure.of(e);
    }
  }

  @override
  Future<AppFailure?> delete(String routineId) async {
    AppLogger.repositoryCall('RoutineRepository', 'delete', {
      'routineId': routineId,
    });

    if (routineId.isEmpty) {
      return const AppFailure(fault: NetworkFault.app);
    }

    try {
      await _dio.delete<void>('/api/routines/$routineId');
      AppLogger.repositorySuccess('RoutineRepository', 'delete', '일과 삭제됨');
      return null;
    } catch (e) {
      AppLogger.repositoryError('RoutineRepository', 'delete', e);
      return AppFailure.of(e);
    }
  }
}
