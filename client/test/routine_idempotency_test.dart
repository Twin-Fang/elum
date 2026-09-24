import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/features/credit/data/credit_repository.dart';
import 'package:elum/features/credit/domain/credit_summary.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/onboarding/domain/support_goal.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/credit_usage.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_reward_api.dart';
import 'helpers/test_storage.dart';

/// 생성 요청 멱등 키 (#407 스펙 §3·§5).
///
/// 같은 키로 다시 오면 서버는 AI 를 다시 부르지 않고 저장된 일과를 돌려준다.
/// 그래서 **재시도는 같은 키**, 새로 만들 때만 새 키여야 한다 — 재시도마다 새 키면
/// 응답이 늦게 왔을 뿐인 요청이 크레딧을 두 번 쓴다.
void main() {
  ProviderContainer makeContainer(RoutineRepository repo) {
    final container = ProviderContainer(
      overrides: [
        testStorageOverride(onboardingCompleted: true),
        routineRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('RoutineFlowNotifier — 멱등 키', () {
    test('생성 요청에 키를 싣는다', () async {
      final repo = _KeyRepo();
      final notifier = makeContainer(repo).read(routineFlowProvider.notifier);

      await notifier.generateCards();

      expect(repo.keys.single, isNotEmpty);
    });

    test('실패 뒤 다시 하기는 같은 키를 쓴다', () async {
      final repo = _KeyRepo(failFirst: true);
      final notifier = makeContainer(repo).read(routineFlowProvider.notifier);

      await notifier.generateCards();
      await notifier.retryGenerate();

      expect(repo.keys, hasLength(2));
      expect(repo.keys[1], repo.keys[0], reason: '재시도는 같은 요청이다');
    });

    test('새 일과(reset 뒤)는 새 키다', () async {
      final repo = _KeyRepo();
      final notifier = makeContainer(repo).read(routineFlowProvider.notifier);

      await notifier.generateCards();
      notifier.reset();
      await notifier.generateCards();

      expect(repo.keys[1], isNot(repo.keys[0]));
    });

    test('실패 뒤 입력을 고쳐 다시 만들면 새 키다', () async {
      final repo = _KeyRepo(failFirst: true);
      final notifier = makeContainer(repo).read(routineFlowProvider.notifier);

      await notifier.generateCards();
      // 되돌아가 보상을 바꿨다 — 다른 요청이다. 옛 키를 쓰면 서버가 옛 요청으로 본다.
      notifier.setReward('젤리 먹기');
      await notifier.retryGenerate();

      expect(repo.keys[1], isNot(repo.keys[0]));
    });

    test('키는 UUID 모양이다', () async {
      final repo = _KeyRepo();
      final notifier = makeContainer(repo).read(routineFlowProvider.notifier);

      await notifier.generateCards();

      expect(
        repo.keys.single,
        matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
      );
    });

    test('생성 응답의 credit 을 흐름 상태에 담는다', () async {
      final repo = _KeyRepo(
        usage: const CreditUsage(cardCount: 5, imageCount: 4, charged: 5, balanceAfter: 67),
      );
      final container = makeContainer(repo);
      await container.read(routineFlowProvider.notifier).generateCards();

      expect(container.read(routineFlowProvider).creditUsage?.balanceAfter, 67);
    });

    test('생성이 끝나면 크레딧 요약을 다시 받게 한다', () async {
      var builds = 0;
      final container = ProviderContainer(
        overrides: [
          testStorageOverride(onboardingCompleted: true),
          routineRepositoryProvider.overrideWithValue(_KeyRepo()),
          creditSummaryProvider.overrideWith((ref) async {
            builds++;
            return const CreditSummary.disabled();
          }),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(creditSummaryProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(creditSummaryProvider.future);
      expect(builds, 1);

      await container.read(routineFlowProvider.notifier).generateCards();
      await container.read(creditSummaryProvider.future);

      expect(builds, 2, reason: '생성 뒤 잔액이 바뀌었으니 다시 받아야 한다');
    });
  });

  group('RoutineRepositoryImpl — Idempotency-Key 헤더', () {
    test('키를 헤더로 보낸다', () async {
      final adapter = _HeaderAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
        ..httpClientAdapter = adapter;

      await RoutineRepositoryImpl(dio: dio).createRoutine(
        rawInputText: '학교 가기',
        goals: const {},
        idempotencyKey: 'k-1',
      );

      expect(adapter.headers?['Idempotency-Key'], 'k-1');
    });

    test('키가 비면 헤더를 보내지 않는다 — 서버가 만든다', () async {
      final adapter = _HeaderAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
        ..httpClientAdapter = adapter;

      await RoutineRepositoryImpl(dio: dio).createRoutine(
        rawInputText: '학교 가기',
        goals: const {},
      );

      expect(adapter.headers?.containsKey('Idempotency-Key'), isFalse);
    });
  });
}

class _KeyRepo with FakeRewardApi implements RoutineRepository {
  _KeyRepo({this.failFirst = false, this.usage});

  final bool failFirst;
  final CreditUsage? usage;
  final keys = <String>[];

  @override
  Future<Routine> createRoutine({
    required String rawInputText,
    required Set<SupportGoal> goals,
    List<String> answers = const [],
    String rewardText = '',
    String rewardPresetKey = '',
    String idempotencyKey = '',
  }) async {
    keys.add(idempotencyKey);
    if (failFirst && keys.length == 1) throw StateError('실패');
    return Routine(
      id: 'r${keys.length}',
      steps: const [ActionCard(id: 's1', description: '가방 챙기기')],
      creditUsage: usage,
    );
  }

  @override
  Future<RoutineQuestion> generateQuestion(String rawInputText) async =>
      const RoutineQuestion();
  @override
  Future<List<Routine>> getMyRoutines() async => const [];
  @override
  Future<List<Routine>> getTodayRoutines() async => const [];
  @override
  Future<List<RoutineSuggestion>> getSuggestions() async => const [];
  @override
  Future<Routine> confirm(Routine routine) async => routine;
  @override
  Future<({Routine routine, AppFailure? failure})> updateStep(
    Routine routine,
    String stepId,
    String description,
  ) async => (routine: routine, failure: null);
  @override
  Future<AppFailure?> deleteStep(String routineId, String stepId) async => null;
}

/// 나간 요청의 헤더를 잡아 둔다.
class _HeaderAdapter implements HttpClientAdapter {
  Map<String, dynamic>? headers;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    headers = options.headers;
    return ResponseBody.fromString(
      jsonEncode({
        'id': 'r1',
        'steps': [
          {'id': 's1', 'stepOrder': 1, 'description': '가방 챙기기'},
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
