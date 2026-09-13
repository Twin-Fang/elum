import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/models/routine.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../../onboarding/domain/support_goal.dart';
import '../domain/routine_suggestion.dart';
import 'demo_cards.dart';
import 'member_repository.dart';

/// 일과 저장소.
///
/// **절대 throw하지 않는다.** 데모는 어떤 실패에도 끝까지 진행되어야 한다 (docs 원칙 6번).
/// 화면은 에러 분기를 쓸 일이 없고, 따라서 빠뜨릴 수도 없다.
abstract interface class RoutineRepository {
  /// AI 추가 질문. 실패하면 "질문 없음"으로 처리해 다음 단계로 넘긴다.
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

  /// 카드 문장 수정.
  ///
  /// [synced]가 false면 서버 반영에 실패해 **로컬에만** 반영됐다는 뜻이다.
  /// 화면이 이 값으로 "서버 저장 실패" 안내를 띄운다 — 실패를 조용히 삼키면
  /// 보호자는 저장된 줄 알고 앱을 끈다.
  Future<({Routine routine, bool synced})> updateStep(
    Routine routine,
    String stepId,
    String description,
  );

  // --- 보상(강화물) · 일과 정리 (이슈 #148~150) ---

  /// 보호자가 정한 보상을 저장한다. [rewardText]가 비면 **보상을 지운다**.
  ///
  /// 실패하면 로컬 반영만 하고 `synced: false`를 준다 — 보상은 선택 항목이라
  /// 저장에 실패했다고 일과 만들기를 막지 않는다. 대신 화면이 안내는 띄운다.
  Future<({Routine routine, bool synced})> updateReward(
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
  Future<Routine?> duplicate(String routineId);

  /// 일과 삭제. 성공 여부를 돌려준다. 실패해도 throw하지 않는다.
  Future<bool> delete(String routineId);
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

    if (AppConfig.useMock) {
      AppLogger.repositorySuccess(
        'RoutineRepository',
        'getMyRoutines',
        '모의 데이터',
      );
      return const [];
    }

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
      AppLogger.repositoryError('RoutineRepository', 'getMyRoutines', e);
      return const [];
    }
  }

  @override
  Future<List<RoutineSuggestion>> getSuggestions() async {
    AppLogger.repositoryCall('RoutineRepository', 'getSuggestions');

    if (AppConfig.useMock) {
      AppLogger.repositorySuccess(
        'RoutineRepository',
        'getSuggestions',
        '모의 데이터 ${RoutineSuggestion.fallback.length}개',
      );
      return RoutineSuggestion.fallback;
    }

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
      AppLogger.repositoryError('RoutineRepository', 'getSuggestions', e);
      return RoutineSuggestion.fallback;
    }
  }

  @override
  Future<RoutineQuestion> generateQuestion(String rawInputText) async {
    AppLogger.repositoryCall('RoutineRepository', 'generateQuestion', {
      'rawInputText': rawInputText,
    });

    if (AppConfig.useMock) {
      final mock = _mockQuestion();
      AppLogger.repositorySuccess(
        'RoutineRepository',
        'generateQuestion',
        mock,
      );
      return mock;
    }

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
    }

    final mock = _mockQuestion();
    AppLogger.repositorySuccess(
      'RoutineRepository',
      'generateQuestion (fallback)',
      mock,
    );
    return mock;
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

    // mock 모드에서만 로컬 데모 일과를 쓴다. 실서버 모드는 절대 가짜 일과를 만들지 않는다
    // — 'local' id로 confirm하면 404가 나고, 아이 모드에 뜨지 않는 유령 일과가 생긴다(데이터 정합성).
    if (AppConfig.useMock) {
      final routine = _localRoutine(rawInputText, goals);
      AppLogger.repositorySuccess(
        'RoutineRepository',
        'createRoutine (mock)',
        '${routine.steps.length}개 카드 mock 생성됨',
      );
      return routine;
    }

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

    if (!AppConfig.useMock && routine.id.isNotEmpty) {
      try {
        final res = await _dio.patch<Map<String, dynamic>>(
          '/api/routines/${routine.id}/confirm',
        );
        final body = res.data;
        if (body != null) {
          final confirmed = Routine.fromJson(body);
          AppLogger.repositorySuccess(
            'RoutineRepository',
            'confirm',
            '일과 승인 완료',
          );
          return confirmed;
        }
      } catch (e) {
        AppLogger.repositoryError('RoutineRepository', 'confirm', e);
      }
    }

    final confirmed = routine.copyWith(status: 'CONFIRMED');
    AppLogger.repositorySuccess(
      'RoutineRepository',
      'confirm (로컬)',
      '로컬 상태로 일과 승인 처리',
    );
    return confirmed;
  }

  @override
  Future<({Routine routine, bool synced})> updateStep(
    Routine routine,
    String stepId,
    String description,
  ) async {
    AppLogger.repositoryCall('RoutineRepository', 'updateStep', {
      'routineId': routine.id,
      'stepId': stepId,
      'description': description,
    });

    // 서버로 보내려 했는데 실패했는가 — 성공·mock과 구분해야 화면이 안내할 수 있다
    var serverFailed = false;

    if (!AppConfig.useMock && routine.id.isNotEmpty) {
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
          return (routine: updated, synced: true);
        }
        serverFailed = true;
      } catch (e) {
        AppLogger.repositoryError('RoutineRepository', 'updateStep', e);
        serverFailed = true;
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
    return (routine: updated, synced: !serverFailed);
  }

  @override
  Future<List<Routine>> getTodayRoutines() async {
    AppLogger.repositoryCall('RoutineRepository', 'getTodayRoutines');

    if (AppConfig.useMock) {
      AppLogger.repositorySuccess(
        'RoutineRepository',
        'getTodayRoutines',
        '모의 데이터',
      );
      return const [];
    }

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
  Future<({Routine routine, bool synced})> updateReward(
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

    var serverFailed = false;

    if (!AppConfig.useMock && routine.id.isNotEmpty) {
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
          return (routine: Routine.fromJson(body), synced: true);
        }
        serverFailed = true;
      } catch (e) {
        AppLogger.repositoryError('RoutineRepository', 'updateReward', e);
        serverFailed = true;
      }
    }

    // 서버에 못 보냈어도 화면에는 반영한다. 보호자가 방금 고른 값이 사라지면
    // 저장이 안 된 건지 잘못 고른 건지 알 수 없다.
    final updated = routine.copyWith(
      rewardText: trimmed,
      rewardPresetKey: rewardPresetKey.trim(),
    );
    return (routine: updated, synced: !serverFailed);
  }

  @override
  Future<List<RecentReward>> getRecentRewards() async {
    AppLogger.repositoryCall('RoutineRepository', 'getRecentRewards');

    if (AppConfig.useMock) return const [];

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
  Future<List<Routine>> getPastRoutines() => _fetchRoutineList(
    '/api/routines/past',
    'getPastRoutines',
  );

  @override
  Future<List<Routine>> getDraftRoutines() => _fetchRoutineList(
    '/api/routines/drafts',
    'getDraftRoutines',
  );

  /// 목록 조회 3종이 같은 모양이라 한 곳에 모았다.
  /// **실패하면 빈 목록이다.** 홈 화면의 한 구역이 비는 것뿐이라 화면은 살아 있다.
  Future<List<Routine>> _fetchRoutineList(String path, String label) async {
    AppLogger.repositoryCall('RoutineRepository', label);

    if (AppConfig.useMock) return const [];

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
      return const [];
    }
  }

  @override
  Future<Routine?> duplicate(String routineId) async {
    AppLogger.repositoryCall('RoutineRepository', 'duplicate', {
      'routineId': routineId,
    });

    if (AppConfig.useMock || routineId.isEmpty) return null;

    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/routines/$routineId/duplicate',
      );
      final body = res.data;
      if (body == null) return null;
      AppLogger.repositorySuccess(
        'RoutineRepository',
        'duplicate',
        '오늘 일과로 복제됨',
      );
      return Routine.fromJson(body);
    } catch (e) {
      // null을 주면 화면이 토스트로 알리고 목록은 그대로 둔다.
      AppLogger.repositoryError('RoutineRepository', 'duplicate', e);
      return null;
    }
  }

  @override
  Future<bool> delete(String routineId) async {
    AppLogger.repositoryCall('RoutineRepository', 'delete', {
      'routineId': routineId,
    });

    if (routineId.isEmpty) return false;
    if (AppConfig.useMock) return true;

    try {
      await _dio.delete<void>('/api/routines/$routineId');
      AppLogger.repositorySuccess('RoutineRepository', 'delete', '일과 삭제됨');
      return true;
    } catch (e) {
      AppLogger.repositoryError('RoutineRepository', 'delete', e);
      return false;
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

  /// 서버가 실패해도 질문 화면을 보여줄 수 있게 하는 대체 질문.
  /// 실제 서버는 목표마다 하나씩 여러 개를 준다.
  ///
  /// 선택지 앞의 이모지는 **서버가 유니코드로 함께 내려준다.** 클라이언트가
  /// 붙이지 않는다 — 선택지는 AI가 생성해 값이 고정되지 않으므로 매핑이 불가능하다.
  /// 폴백도 실제 응답과 같은 모양이어야 서버가 죽었을 때만 화면이 달라 보이지 않는다.
  RoutineQuestion _mockQuestion() => const RoutineQuestion(
    isRequired: true,
    questions: [
      QuestionItem(
        question: '꼭 챙겨야 하는 준비물이 있나요?',
        options: [
          QuestionOption(emoji: '☂️', label: '우산'),
          QuestionOption(emoji: '🧥', label: '우비'),
          QuestionOption(emoji: '👢', label: '장화'),
          QuestionOption(emoji: '🧦', label: '여벌 양말'),
          QuestionOption(emoji: '🧺', label: '작은 수건'),
        ],
      ),
    ],
  );

  /// 서버 없이도 데모가 성립하도록 로컬에서 일과를 구성한다.
  /// DLP 마스킹도 여기서 흉내낸다 — 발표에서 전/후 비교를 보여줘야 하기 때문이다.
  Routine _localRoutine(String rawInputText, Set<SupportGoal> goals) {
    return Routine(
      id: 'local',
      title: '비 오는 날 학교 가기',
      rawInputText: rawInputText,
      sanitizedInputText: LocalDlp.mask(rawInputText),
      status: 'PENDING_REVIEW',
      steps: DemoCards.forGoals(goals),
    );
  }
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

/// 최근 일과 목록. 보호자_홈이 구독한다.
final myRoutinesProvider = FutureProvider<List<Routine>>((ref) {
  return ref.watch(routineRepositoryProvider).getMyRoutines();
});

/// 오늘 할 일 목록. 아이_홈이 구독한다 (이슈 #75).
final todayRoutinesProvider = FutureProvider<List<Routine>>((ref) {
  return ref.watch(routineRepositoryProvider).getTodayRoutines();
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
