import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/onboarding/domain/support_goal.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_storage.dart';

/// `POST /api/routines`는 AI 호출이라 **한 번이 곧 비용**이다.
///
/// 실제로 한 번의 일과 생성에 요청이 16번 나간 사고가 있었다. 로딩 화면이
/// 재생성되면(토큰 만료로 라우터가 시작 화면으로 튕김, 화면 복귀 등)
/// `initState`가 다시 돌아 `generateCards()`를 또 불렀다.
///
/// 위젯이 아니라 notifier에서 막는다 — 위젯은 몇 번이든 다시 만들어지지만
/// provider는 흐름이 끝날 때까지 살아 있다.
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

  group('카드 생성은 한 번만 나간다', () {
    test('generateCards를 여러 번 불러도 서버 요청은 1회다', () async {
      final repo = _CountingRepo();
      final container = makeContainer(repo);
      final notifier = container.read(routineFlowProvider.notifier);

      // 로딩 화면이 여러 번 재생성된 상황을 그대로 재현한다
      await Future.wait([
        notifier.generateCards(),
        notifier.generateCards(),
        notifier.generateCards(),
        notifier.generateCards(),
      ]);

      expect(repo.createCalls, 1, reason: 'AI 호출은 한 번이 곧 비용이다');
    });

    test('생성이 끝난 뒤 다시 불러도 재요청하지 않는다', () async {
      final repo = _CountingRepo();
      final container = makeContainer(repo);
      final notifier = container.read(routineFlowProvider.notifier);

      await notifier.generateCards();
      // 화면 복귀 등으로 initState가 또 돈 경우
      await notifier.generateCards();

      expect(repo.createCalls, 1);
    });

    test('reset 후에는 새 일과를 생성할 수 있다', () async {
      final repo = _CountingRepo();
      final container = makeContainer(repo);
      final notifier = container.read(routineFlowProvider.notifier);

      await notifier.generateCards();
      // 가드를 안 풀면 다음 일과 생성이 영영 막힌다
      notifier.reset();
      await notifier.generateCards();

      expect(repo.createCalls, 2);
    });

    test('실패해도 가드가 풀려 재시도할 수 있다', () async {
      final repo = _ThrowingRepo();
      final container = makeContainer(repo);
      final notifier = container.read(routineFlowProvider.notifier);

      // repository는 원래 예외를 삼키지만, 그래도 새어 나오는 경우를 막는다
      await expectLater(notifier.generateCards(), throwsA(isA<Exception>()));
      await expectLater(notifier.generateCards(), throwsA(isA<Exception>()));

      expect(repo.createCalls, 2, reason: '실패가 재시도를 영구히 막으면 안 된다');
    });
  });
}

/// 호출 횟수를 세는 저장소. 실서버를 타지 않는다.
class _CountingRepo implements RoutineRepository {
  var createCalls = 0;

  @override
  Future<Routine> createRoutine({
    required String rawInputText,
    required Set<SupportGoal> goals,
    List<String> answers = const [],
  }) async {
    createCalls++;
    // 실제 AI 호출처럼 시간이 걸린다 — 그 사이 중복 호출이 들어온다
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return const Routine(id: 'test');
  }

  @override
  Future<RoutineQuestion> generateQuestion(String rawInputText) async =>
      const RoutineQuestion(isRequired: false);

  @override
  Future<List<Routine>> getMyRoutines() async => const [];

  @override
  Future<List<RoutineSuggestion>> getSuggestions() async =>
      RoutineSuggestion.fallback;

  @override
  Future<Routine> confirm(Routine routine) async => routine;

  @override
  Future<Routine> updateStep(
    Routine routine,
    String stepId,
    String description,
  ) async =>
      routine;
}

/// 항상 실패하는 저장소. 가드가 풀리는지 확인한다.
class _ThrowingRepo extends _CountingRepo {
  @override
  Future<Routine> createRoutine({
    required String rawInputText,
    required Set<SupportGoal> goals,
    List<String> answers = const [],
  }) async {
    createCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    throw Exception('서버 502');
  }
}
