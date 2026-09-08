import 'dart:async';

import 'package:dio/dio.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/child/application/child_routine_notifier.dart';
import 'package:elum/features/child/data/progress_store.dart';
import 'package:elum/features/child/data/step_progress_repository.dart';
import 'package:elum/features/child/domain/routine_progress_record.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 카드 완료 체크의 오프라인 퍼스트 동기화 (이슈 #140).
///
/// 기기가 진실이다. 탭하면 즉시 저장되고, 서버 반영은 뒤에서 따라온다.
/// - 서버에 못 닿으면 기록과 대기열을 유지하고 다음에 다시 보낸다
/// - 서버가 거부하면 로컬 기록을 버리고 서버 값으로 돌아간다
/// - 앱을 다시 열면 저장된 기록이 복원된다
void main() {
  const c1 = ActionCard(id: 'c1', description: '옷을 입어요', stepOrder: 1);
  const c2 = ActionCard(id: 'c2', description: '우산을 챙겨요', stepOrder: 2);
  const c3 = ActionCard(id: 'c3', description: '신발을 신어요', stepOrder: 3);
  const routine = Routine(
    id: 'r1',
    title: '비 오는 날 학교에 가요',
    status: 'CONFIRMED',
    steps: [c1, c2, c3],
  );

  ({ProviderContainer container, _FakeSyncRepo repo, InMemoryStorage storage})
  setUp({
    SyncOutcome outcome = SyncOutcome.accepted,
    InMemoryStorage? storage,
  }) {
    final repo = _FakeSyncRepo(outcome: outcome);
    final mem = storage ?? InMemoryStorage(onboardingCompleted: true);
    final container = ProviderContainer(
      overrides: [
        localStorageProvider.overrideWithValue(mem),
        stepProgressRepositoryProvider.overrideWithValue(repo),
        todayRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
        myRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, repo: repo, storage: mem);
  }

  Future<void> drain() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('체크는 즉시 로컬에 반영되고 서버에는 집합으로 간다', () {
    test('아무 순서로나 체크할 수 있다', () async {
      final (:container, :repo, storage: _) = setUp();
      final notifier = container.read(childRoutineProvider.notifier);

      notifier.toggle(routine: routine, card: c3);
      notifier.toggle(routine: routine, card: c1);
      await drain();

      final state = container.read(childRoutineProvider);
      expect(state.isChecked('r1', c3), isTrue);
      expect(state.isChecked('r1', c1), isTrue);
      expect(state.isChecked('r1', c2), isFalse);
      expect(repo.lastSent, {'c3', 'c1'});
    });

    test('서버 완료 카드를 해제하면 집합에서 빠져서 전송된다', () async {
      const serverDone = ActionCard(
        id: 'c1',
        description: '옷을 입어요',
        stepOrder: 1,
        completed: true,
      );
      const resumed = Routine(
        id: 'r1',
        status: 'CONFIRMED',
        steps: [serverDone, c2, c3],
      );
      final (:container, :repo, storage: _) = setUp();
      final notifier = container.read(childRoutineProvider.notifier);

      expect(
        container.read(childRoutineProvider).isChecked('r1', serverDone),
        isTrue,
      );
      notifier.toggle(routine: resumed, card: serverDone);
      await drain();

      expect(
        container.read(childRoutineProvider).isChecked('r1', serverDone),
        isFalse,
      );
      expect(repo.lastSent, isEmpty);
    });

    test('탭할 때마다 저장소에 기록된다', () async {
      final (:container, repo: _, :storage) = setUp();
      container
          .read(childRoutineProvider.notifier)
          .toggle(routine: routine, card: c1);
      await drain();

      expect(ProgressStore(storage).load('r1')?.completed, {'c1'});
    });
  });

  group('오프라인 — 서버에 못 닿아도 기록은 남는다', () {
    test('unreachable이면 체크가 유지되고 대기열에 남는다', () async {
      final (:container, repo: _, :storage) = setUp(
        outcome: SyncOutcome.unreachable,
      );
      container
          .read(childRoutineProvider.notifier)
          .toggle(routine: routine, card: c1);
      await drain();

      final state = container.read(childRoutineProvider);
      expect(state.isChecked('r1', c1), isTrue);
      expect(state.pending, contains('r1'));
      expect(ProgressStore(storage).pending, contains('r1'));
    });

    test('온라인 복귀 후 syncPending이 대기열을 비운다', () async {
      final (:container, :repo, storage: _) = setUp(
        outcome: SyncOutcome.unreachable,
      );
      final notifier = container.read(childRoutineProvider.notifier);
      notifier.toggle(routine: routine, card: c1);
      await drain();
      expect(container.read(childRoutineProvider).pending, contains('r1'));

      repo.outcome = SyncOutcome.accepted;
      notifier.syncPending();
      await drain();

      expect(container.read(childRoutineProvider).pending, isEmpty);
      expect(repo.lastSent, {'c1'});
      // 반영됐어도 로컬 기록은 남는다 — 다음 오프라인 때 보여줄 값이다
      expect(container.read(childRoutineProvider).isChecked('r1', c1), isTrue);
    });
  });

  group('서버 거부 — 로컬을 버리고 서버 값으로 돌아간다', () {
    test('rejected면 기록과 대기열이 사라진다', () async {
      final (:container, repo: _, :storage) = setUp(
        outcome: SyncOutcome.rejected,
      );
      container
          .read(childRoutineProvider.notifier)
          .toggle(routine: routine, card: c1);
      await drain();

      final state = container.read(childRoutineProvider);
      expect(state.progress.containsKey('r1'), isFalse);
      expect(state.pending, isEmpty);
      expect(ProgressStore(storage).load('r1'), isNull);
      // 로컬이 없으니 서버 값(미완료)으로 보인다
      expect(state.isChecked('r1', c1), isFalse);
    });
  });

  group('재시작 — hydrate로 복원한다', () {
    test('저장된 기록과 대기열이 상태로 돌아온다', () async {
      final storage = InMemoryStorage(onboardingCompleted: true);
      final store = ProgressStore(storage);
      await store.save(
        'r1',
        const RoutineProgressRecord(completed: {'c1', 'c2'}, rewarded: {'c1'}),
      );
      await store.setPending({'r1'});

      final (:container, repo: _, storage: _) = setUp(
        outcome: SyncOutcome.unreachable,
        storage: storage,
      );
      await container.read(childRoutineProvider.notifier).hydrate();
      await drain();

      final state = container.read(childRoutineProvider);
      expect(state.isChecked('r1', c2), isTrue);
      expect(state.hasRewarded('r1', 'c1'), isTrue);
      expect(state.pending, contains('r1'));
    });

    test('hydrate 직후 대기열 동기화를 시도한다', () async {
      final storage = InMemoryStorage(onboardingCompleted: true);
      final store = ProgressStore(storage);
      await store.save('r1', const RoutineProgressRecord(completed: {'c1'}));
      await store.setPending({'r1'});

      final (:container, :repo, storage: _) = setUp(storage: storage);
      await container.read(childRoutineProvider.notifier).hydrate();
      await drain();

      expect(repo.lastSent, {'c1'});
      expect(container.read(childRoutineProvider).pending, isEmpty);
    });
  });

  group('동기화 중 추가 조작', () {
    test('전송 중에 또 체크하면 대기열이 유지되고 최신 집합이 다시 간다', () async {
      final (:container, :repo, storage: _) = setUp();
      repo.hold = true;
      final notifier = container.read(childRoutineProvider.notifier);

      notifier.toggle(routine: routine, card: c1); // 전송 시작(대기)
      await drain();
      notifier.toggle(routine: routine, card: c2); // 전송 중 추가
      repo.releaseAll();
      await drain();
      repo.releaseAll();
      await drain();

      expect(repo.sent.last, {'c1', 'c2'});
      expect(container.read(childRoutineProvider).pending, isEmpty);
    });
  });

  group('보상 규칙', () {
    test('처음 체크하면 보상, 해제 후 재체크는 보상 없음', () async {
      final (:container, repo: _, storage: _) = setUp();
      final notifier = container.read(childRoutineProvider.notifier);

      expect(notifier.toggle(routine: routine, card: c1), isTrue);
      expect(notifier.toggle(routine: routine, card: c1), isFalse);
      expect(notifier.toggle(routine: routine, card: c1), isFalse);
      await drain();

      expect(
        container.read(childRoutineProvider).hasRewarded('r1', 'c1'),
        isTrue,
      );
    });
  });
}

/// 서버 대신 전송된 집합을 기록하는 가짜 저장소.
class _FakeSyncRepo extends StepProgressRepository {
  _FakeSyncRepo({required this.outcome}) : super(dio: Dio());

  SyncOutcome outcome;
  bool hold = false;
  final sent = <Set<String>>[];
  final _pending = <Completer<void>>[];

  Set<String>? get lastSent => sent.isEmpty ? null : sent.last;

  @override
  Future<SyncOutcome> syncProgress({
    required String routineId,
    required Set<String> completedStepIds,
  }) async {
    sent.add(Set.of(completedStepIds));
    if (hold) {
      final c = Completer<void>();
      _pending.add(c);
      await c.future;
    }
    return outcome;
  }

  void releaseAll() {
    for (final c in _pending) {
      if (!c.isCompleted) c.complete();
    }
    _pending.clear();
  }
}
