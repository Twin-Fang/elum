
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/shared/models/support_goal.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_reward_api.dart';
import 'helpers/test_storage.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';

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

    test('실패 뒤 입력을 고쳐 다시 만들면 새 키다', () async {
      final repo = _KeyRepo(failFirst: true);
      final notifier = makeContainer(repo).read(routineFlowProvider.notifier);

      await notifier.generateCards();
      // 되돌아가 보상을 바꿨다 — 다른 요청이다. 옛 키를 쓰면 서버가 옛 요청으로 본다.
      notifier.setReward('젤리 먹기');
      await notifier.retryGenerate();

      expect(repo.keys[1], isNot(repo.keys[0]));
    });

  });

  group('RoutineRepositoryImpl — Idempotency-Key 헤더', () {
  });
}

class _KeyRepo with FakeRewardApi implements RoutineRepository {
  // 카드확인 카드 추가 (#444) — 이 테스트는 쓰지 않는다
  @override
  Future<({Routine routine, AppFailure? failure})> addStep(
    Routine routine, {
    required String title,
    required String description,
  }) async => (routine: routine, failure: null);
  _KeyRepo({this.failFirst = false});

  final bool failFirst;
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
    String stepId, {
    required String title,
    required String description,
  }) async => (routine: routine, failure: null);
  @override
  Future<AppFailure?> deleteStep(String routineId, String stepId) async => null;
}

/// 나간 요청의 헤더를 잡아 둔다.