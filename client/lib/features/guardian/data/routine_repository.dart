import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/models/routine.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../../onboarding/domain/support_goal.dart';
import '../domain/routine_suggestion.dart';
import 'member_repository.dart';

/// 일과 저장소.
///
/// **절대 throw하지 않는다.** 데모는 어떤 실패에도 끝까지 진행되어야 한다 (docs 원칙 6번).
/// 화면은 에러 분기를 쓸 일이 없고, 따라서 빠뜨릴 수도 없다.
abstract interface class RoutineRepository {
  /// AI 추가 질문.
  ///
  /// - 서버가 응답은 했는데 실패면 **질문 없음**을 준다 — 카드 만들기로 넘어간다.
  /// - 서버에 **닿지 못했으면** [AppFailure] 를 던진다. 다음 단계(카드 만들기)도
  ///   어차피 실패하므로 흐름이 연결 안내와 다시 하기를 띄운다 (#393 S1 · #352).
  ///
  /// 어느 쪽이든 **입력과 무관한 대체 질문은 만들지 않는다** (#393 S1).
  Future<RoutineQuestion> generateQuestion(String rawInputText);

  /// 내가 만든 일과 목록 — 보호자_홈의 "최근 일과".
  /// 실패하면 빈 목록을 준다. 화면은 빈 상태 UI를 그린다.
  Future<List<Routine>> getMyRoutines();

  /// 오늘 할 일 — 아이 홈 목록 (이슈 #75, `GET /api/routines/today`).
  ///
  /// 서버가 오늘(KST) + CONFIRMED/COMPLETED만 진행률과 함께 예정 시각순으로 준다.
  /// 실패하면 [getMyRoutines]로 폴백한다 — 아이 목록이 비는 것보다
  /// 클라이언트 필터로라도 보여주는 쪽이 낫다 (docs 원칙 6번).
  Future<List<Routine>> getTodayRoutines();

  /// 추천 일과 — 보호자_홈 타일과 일과 만들기 화면의 칩.
  /// 실패하면 [RoutineSuggestion.fallback]을 준다. 추천이 비면 화면 한 블록이
  /// 통째로 사라져 빈 화면처럼 보이기 때문이다.
  Future<List<RoutineSuggestion>> getSuggestions();

  /// 일과 생성 → 카드 5장.
  ///
  /// [rewardText]는 보호자가 카드 생성 **전에** 정한 보상이다. 비워둘 수 있다.
  Future<Routine> createRoutine({
    required String rawInputText,
    required Set<SupportGoal> goals,
    List<String> answers,
    String rewardText,
    String rewardPresetKey,
  });

  /// 보호자 승인. 이후에만 아동 화면에 노출된다 (docs 원칙 3번).
  Future<Routine> confirm(Routine routine);

  /// 카드 한 장을 일과에서 뺀다 (이슈 #405).
  ///
  /// 카드확인의 X 는 화면에서만 지우고, **저장하기가 이것으로 서버에 반영한다** —
  /// 나가기 팝업이 "뺀 카드는 저장하기를 눌러야 빠져요"라고 약속하는 그 동작이다.
  /// 승인([confirm])은 본문 없이 상태만 바꾸므로 여기를 거치지 않으면 뺀 카드가
  /// 서버에 그대로 남는다.
  ///
  /// null 이면 성공. 실패하면 서버가 알려준 이유가 담겨 온다 (#352).
  Future<AppFailure?> deleteStep(String routineId, String stepId);

  /// 카드 문장 수정.
  ///
  /// [failure]가 null이 아니면 서버 반영에 실패해 **로컬에만** 반영됐다는 뜻이다.
  /// 그 안에 서버가 알려준 이유가 들어 있다 — 화면이 그대로 띄운다 (#352).
  /// 화면이 이 값으로 "서버 저장 실패" 안내를 띄운다 — 실패를 조용히 삼키면
  /// 보호자는 저장된 줄 알고 앱을 끈다.
  Future<({Routine routine, AppFailure? failure})> updateStep(
    Routine routine,
    String stepId,
    String description,
  );

  // --- 보상(강화물) · 일과 정리 (이슈 #148~150) ---

  /// 보호자가 정한 보상을 저장한다. [rewardText]가 비면 **보상을 지운다**.
  ///
  /// 실패하면 로컬 반영만 하고 실패 이유를 함께 준다 — 보상은 선택 항목이라
  /// 저장에 실패했다고 일과 만들기를 막지 않는다. 대신 화면이 안내는 띄운다.
  Future<({Routine routine, AppFailure? failure})> updateReward(
    Routine routine, {
    required String rewardText,
    String rewardPresetKey,
  });

  /// 최근에 정한 보상 — 보상 설정 화면 상단의 재사용 칩.
  /// 실패하면 **빈 목록**이다. 화면은 섹션을 통째로 숨긴다 (없어도 되는 기능이다).
  Future<List<RecentReward>> getRecentRewards();

  /// 지난 일과 — 보호자 홈의 접힌 구역. 실패하면 빈 목록.
  Future<List<Routine>> getPastRoutines();

  /// 임시저장 — 카드는 만들었지만 아직 아이에게 보내지 않은 것. 실패하면 빈 목록.
  Future<List<Routine>> getDraftRoutines();

  /// 지난 일과 다시 하기. 서버가 오늘 날짜로 복제해 돌려준다.
  /// 실패하면 **null** — 화면이 토스트로 알리고 목록은 그대로 둔다.
  /// 성공하면 복제된 일과, 실패하면 **이유**가 담겨 온다 (#352).
  Future<Attempt<Routine>> duplicate(String routineId);

  /// 일과 삭제. 성공 여부를 돌려준다. 실패해도 throw하지 않는다.
  /// null 이면 성공. 실패하면 서버가 알려준 이유가 담겨 온다 (#352).
  Future<AppFailure?> delete(String routineId);

  /// 홈 목록의 순서를 통째로 저장한다.
  ///
  /// 화면에 보이는 **전체**를 차례대로 보낸다. 일부만 보내는 방식이 아니다 —
  /// 부분 갱신은 두 곳에서 동시에 순서를 바꿀 때 뒤엉킨다.
  /// null 이면 성공. 실패하면 서버가 알려준 이유가 담겨 온다 (#352).
  Future<AppFailure?> reorder(List<String> routineIds);

  /// 일과 안의 행동 단계 순서를 바꾼다.
  ///
  /// 일과 순서([reorder])와 같은 방식이다 — **화면에 보이는 단계 전체를 차례대로**
  /// 보낸다. 실패하면 false를 주고, 부르는 쪽이 화면을 되돌린다.
  /// null 이면 성공. 실패하면 서버가 알려준 이유가 담겨 온다 (#352).
  Future<AppFailure?> reorderSteps(String routineId, List<String> stepIds);
}

class RoutineRepositoryImpl implements RoutineRepository {
  RoutineRepositoryImpl({Dio? dio, LocalStorage? storage})
    : _dio = dio ?? DioClient.create(),
      _storage = storage;

  final Dio _dio;

  /// 오늘 일과 캐시용. null이면 캐시 없이 동작한다(기존 테스트 호환).
  final LocalStorage? _storage;

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
    AppLogger.repositoryCall('RoutineRepository', 'generateQuestion', {
      'rawInputText': rawInputText,
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
      // 서버에 닿지 못했다 — 흐름이 연결 안내를 띄우게 넘긴다 (#393 S1).
      final failure = AppFailure.of(e);
      if (failure.isUnreachable) throw failure;
    }

    // 응답은 받았는데 실패했다(5xx·빈 본문 등). 예전에는 여기서 `비 오는 날
    // 준비물` 대체 질문을 줬는데, 수영장 가기를 적어도 우산을 물었다 (#393 S1).
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
  }) async {
    AppLogger.repositoryCall('RoutineRepository', 'createRoutine', {
      'rawInputText': rawInputText,
      'goals': goals.map((g) => g.apiValue).toList(),
      'answers': answers,
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
  Future<({Routine routine, AppFailure? failure})> updateStep(
    Routine routine,
    String stepId,
    String description,
  ) async {
    AppLogger.repositoryCall('RoutineRepository', 'updateStep', {
      'routineId': routine.id,
      'stepId': stepId,
      'description': description,
    });

    // 서버로 보내려 했는데 왜 실패했는가 — **이유까지 들고 나간다.**
    // `false` 로 납작하게 만들면 서버가 알려준 문구가 여기서 사라진다 (#352).
    AppFailure? failure;

    if (routine.id.isNotEmpty) {
      try {
        final res = await _dio.patch<Map<String, dynamic>>(
          '/api/routines/${routine.id}/steps/$stepId',
          data: {'description': description},
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
            step.copyWith(description: description)
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
        // 성공한 응답을 캐시해 둔다 — 다음에 오프라인이면 이걸 보여준다 (이슈 #140)
        await _storage?.setCachedTodayRoutinesJson(
          jsonEncode(routines.map((r) => r.toJson()).toList()),
        );
        return routines;
      }
    } catch (e) {
      AppLogger.repositoryError('RoutineRepository', 'getTodayRoutines', e);
    }

    // 오프라인이거나 서버가 죽었다 — 마지막 성공 응답이 있으면 그걸 쓴다.
    final cached = _readCachedToday();
    if (cached != null) {
      AppLogger.repositorySuccess(
        'RoutineRepository',
        'getTodayRoutines (캐시)',
        '${cached.length}개 오프라인 캐시 사용',
      );
      return cached;
    }

    // 캐시도 없으면 전체 조회로 폴백. 승인 여부 필터는 화면 provider가 한 번 더 거른다 (docs 원칙 3번).
    AppLogger.repositorySuccess(
      'RoutineRepository',
      'getTodayRoutines (폴백)',
      '전체 일과 조회로 대체',
    );
    return getMyRoutines();
  }

  // --- 보상(강화물) · 일과 정리 (이슈 #148~150) ---

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
  Future<AppFailure?> reorderSteps(String routineId, List<String> stepIds) async {
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

  @override
  Future<AppFailure?> deleteStep(String routineId, String stepId) async {
    AppLogger.repositoryCall('RoutineRepository', 'deleteStep', {
      'routineId': routineId,
      'stepId': stepId,
    });

    if (routineId.isEmpty || stepId.isEmpty) {
      return const AppFailure(fault: NetworkFault.app);
    }

    try {
      // 응답으로 일과 전체가 오지만 쓰지 않는다 — 서버 응답에는 카드 제목이 없어
      // (RoutineStep 에 title 컬럼이 없다, #77) 그대로 받으면 로컬 제목이 지워진다.
      await _dio.delete<void>('/api/routines/$routineId/steps/$stepId');
      AppLogger.repositorySuccess('RoutineRepository', 'deleteStep', '카드 빠짐');
      return null;
    } catch (e) {
      AppLogger.repositoryError('RoutineRepository', 'deleteStep', e);
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

  /// 캐시가 깨져 있으면 null — 폴백으로 넘긴다. 캐시 한 건 때문에 화면이 죽으면 안 된다.
  List<Routine>? _readCachedToday() {
    final json = _storage?.cachedTodayRoutinesJson;
    if (json == null) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Routine.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  // --- 로컬 대체 구현 ---

  /// 서버 없이도 데모가 성립하도록 로컬에서 일과를 구성한다.
  /// DLP 마스킹도 여기서 흉내낸다 — 발표에서 전/후 비교를 보여줘야 하기 때문이다.
}

/// 서버가 없을 때 쓰는 로컬 마스킹.
///
/// 실제 DLP는 서버(AI DLP Gateway)가 담당한다. 이건 **데모 대비용**이며,
/// 서버가 붙으면 `sanitizedInputText`를 그대로 쓴다.
abstract final class LocalDlp {
  /// 탐지 유형 4종 — 데모 성립 조건 (docs/07-mvp-scope.md)
  static final _patterns = <String, RegExp>{
    '전화번호': RegExp(r'01[0-9]-?\d{3,4}-?\d{4}'),
    '이메일': RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+'),
    '학교명': RegExp(r'[가-힣]+(초등학교|중학교|고등학교|학교)'),
  };

  static String mask(String input) {
    var result = input;
    _patterns.forEach((label, pattern) {
      result = result.replaceAll(pattern, '<$label>');
    });
    return result;
  }

  /// 탐지된 유형 목록. **원문은 담지 않는다** — 유형·건수만 남긴다 (docs 원칙 5번).
  static List<String> detectedTypes(String input) {
    return [
      for (final entry in _patterns.entries)
        if (entry.value.hasMatch(input)) entry.key,
    ];
  }
}

/// 일과 저장소. 인증 인터셉터가 붙은 [dioProvider]를 쓴다 —
/// 직접 `DioClient.create()`를 부르면 토큰이 빠져 401이 그대로 터진다.
final routineRepositoryProvider = Provider<RoutineRepository>(
  (ref) => RoutineRepositoryImpl(
    dio: ref.watch(dioProvider),
    storage: ref.watch(localStorageProvider),
  ),
);

/// 이 계정의 일과 **전부**. 날짜도 상태도 가리지 않는다.
///
/// **오늘 일과 자리에 쓰지 않는다** — 보호자 홈이 이것을 보고 있어서 어제 것도,
/// 아직 이룸이에게 보내지 않은 것(`PENDING_REVIEW`)도 오늘 할 일로 보였다.
/// 오늘 목록은 [todayRoutinesProvider] 다 (#353).
///
/// 전체가 필요한 곳(임시저장 거르기 등)만 쓴다.
final myRoutinesProvider = FutureProvider<List<Routine>>((ref) {
  return ref.watch(routineRepositoryProvider).getMyRoutines();
});

/// 임시저장 — 만들다 만 일과 (이슈 #349).
///
/// 서버의 `PENDING_REVIEW` 가 곧 임시저장이다. 카드까지 만들어졌지만 보호자가
/// 아직 확인하지 않은 상태다. **`승인 대기`라 부르지 않는다** — 만들다 만 것이지
/// 심사가 아니다 (용어 규칙).
///
/// 전용 API 를 따로 두지 않고 내 일과 목록에서 걸러 쓴다. 목록이 길어지면
/// 서버에 상태 필터를 다는 편이 낫지만, 지금은 한 보호자의 일과가 많지 않다.
final draftRoutinesProvider = FutureProvider<List<Routine>>((ref) async {
  final all = await ref.watch(myRoutinesProvider.future);
  return all.where((r) => r.status == 'PENDING_REVIEW').toList();
});

/// 오늘 할 일 목록. **보호자 홈과 이룸이 홈이 같이 본다** (이슈 #75 · #353).
///
/// 서버가 `scheduledAt` 이 오늘이고 `CONFIRMED`·`COMPLETED` 인 것만 준다.
/// 승인하면 서버가 `scheduledAt` 을 그날로 옮기므로(`RoutineService.confirm` —
/// *"승인한 날이 곧 그 일과를 하는 날이다"*), **오늘 못 한 일과는 다음 날이
/// 되면 저절로 지난 일과로 넘어간다.**
///
/// 보호자 홈이 이것을 안 보고 전체 목록을 보고 있어서, 보호자가 "오늘 할 일"로
/// 믿는 것과 이룸이 화면에 뜨는 것이 서로 달랐다 (#353).
final todayRoutinesProvider = FutureProvider<List<Routine>>((ref) {
  return ref.watch(routineRepositoryProvider).getTodayRoutines();
});

/// 지난 일과 목록. 보호자_홈 아래쪽 구역이 구독한다 (이슈 #258).
///
/// 오늘 목록과 따로 받는다 — 지난 일과는 자주 바뀌지 않아 오늘 목록이 갱신될 때마다
/// 함께 부를 이유가 없다.
final pastRoutinesProvider = FutureProvider<List<Routine>>((ref) {
  return ref.watch(routineRepositoryProvider).getPastRoutines();
});

/// 추천 일과. 보호자_홈 타일과 일과 만들기 화면의 칩이 함께 구독한다.
///
/// 서버가 매 호출마다 셔플하므로 두 화면이 각자 부르면 목록이 달라진다.
/// 같은 provider를 공유해 한 번만 받아 쓴다.
final routineSuggestionsProvider = FutureProvider<List<RoutineSuggestion>>((
  ref,
) {
  return ref.watch(routineRepositoryProvider).getSuggestions();
});

/// 회원 정보. 실패하면 null이고 화면은 로컬 온보딩 값으로 fallback한다.
final memberProvider = FutureProvider<Member?>((ref) {
  return MemberRepository(dio: ref.watch(dioProvider)).getMyInfo();
});


/// 일과 목록을 **세 개 다** 다시 받는다.
///
/// 목록이 셋으로 나뉘어 산다 — 오늘([todayRoutinesProvider]) · 지난
/// ([pastRoutinesProvider]) · 전체([myRoutinesProvider], 임시저장이 여기서
/// 걸러 쓴다). 하나를 바꾸면 나머지도 달라질 수 있다. 일과를 지우면 오늘에서도
/// 빠지고 전체에서도 빠진다.
///
/// **한쪽만 무효화하면 화면마다 다른 것을 보게 된다.** 그 일이 실제로 있었다 —
/// 홈이 전체 목록을 보고 있어서 어제 것과 승인 전 것이 오늘 할 일에 섞였다
/// (#353). 부르는 쪽이 매번 셋을 기억하지 않도록 한 곳에 묶는다.
extension RoutineListRefresh on WidgetRef {
  void refreshRoutines() {
    invalidate(todayRoutinesProvider);
    invalidate(pastRoutinesProvider);
    invalidate(myRoutinesProvider);
  }
}

/// 화면을 떠난 뒤(위젯이 사라진 뒤)에 부를 때 쓰는 같은 것 — 컨테이너를 붙잡아 둔다.
extension RoutineListRefreshContainer on ProviderContainer {
  void refreshRoutines() {
    invalidate(todayRoutinesProvider);
    invalidate(pastRoutinesProvider);
    invalidate(myRoutinesProvider);
  }
}

/// notifier 쪽에서 쓰는 같은 것.
extension RoutineListRefreshRef on Ref {
  void refreshRoutines() {
    invalidate(todayRoutinesProvider);
    invalidate(pastRoutinesProvider);
    invalidate(myRoutinesProvider);
  }
}
