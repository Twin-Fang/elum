import 'package:dio/dio.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/child/application/child_routine_notifier.dart';
import 'package:elum/features/child/application/sync_triggers.dart';
import 'package:elum/features/child/data/progress_store.dart';
import 'package:elum/features/child/data/step_progress_repository.dart';
import 'package:elum/features/child/domain/routine_progress_record.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';

/// 동기화 트리거 (이슈 #140) — 앱 시작 시 복원·전송, 복귀 시 재전송.
///
/// 온라인 전환(connectivity_plus)은 플랫폼 채널이라 위젯 테스트로 고정하지 않는다.
/// 대신 이벤트 발생 시 호출되는 경로가 복귀 경로와 같음을 코드로 보장한다.
void main() {
  Future<void> pumpTriggers(
    WidgetTester tester, {
    required InMemoryStorage storage,
    required StepProgressRepository repo,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
          stepProgressRepositoryProvider.overrideWithValue(repo),
          todayRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
          myRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
        ],
        child: const SyncTriggers(child: SizedBox.shrink()),
      ),
    );
  }

  testWidgets('시작하면 저장된 대기열을 복원하고 전송한다', (tester) async {
    final storage = InMemoryStorage(onboardingCompleted: true);
    final store = ProgressStore(storage);
    await store.save('r1', const RoutineProgressRecord(completed: {'c1'}));
    await store.setPending({'r1'});
    final repo = _CountingRepo();

    await pumpTriggers(tester, storage: storage, repo: repo);
    await tester.pumpAndSettle();

    expect(repo.calls, 1);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SyncTriggers)),
    );
    expect(container.read(childRoutineProvider).pending, isEmpty);
  });

  testWidgets('백그라운드에서 돌아오면 대기열을 다시 전송한다', (tester) async {
    final storage = InMemoryStorage(onboardingCompleted: true);
    final store = ProgressStore(storage);
    await store.save('r1', const RoutineProgressRecord(completed: {'c1'}));
    await store.setPending({'r1'});
    final repo = _CountingRepo(outcome: SyncOutcome.unreachable);

    await pumpTriggers(tester, storage: storage, repo: repo);
    await tester.pumpAndSettle();
    expect(repo.calls, 1); // 시작 시 1회 — 실패해서 대기열 유지

    repo.outcome = SyncOutcome.accepted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(repo.calls, 2);
  });

  group('날짜가 바뀌면 오늘 일과를 다시 받는다 (이슈 #353)', () {
    // 오늘 일과 provider 는 앱이 살아 있는 동안 값을 들고 있다. 자정을 넘겨도 다시
    // 받지 않으면 어제 일과가 오늘 일과로 남는다 — 앱을 다시 켜야만 초기화됐다.
    late DateTime clock;
    late int todayFetches;

    Future<ProviderContainer> pumpWithClock(WidgetTester tester) async {
      todayFetches = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageProvider.overrideWithValue(
              InMemoryStorage(onboardingCompleted: true),
            ),
            stepProgressRepositoryProvider.overrideWithValue(_CountingRepo()),
            todayRoutinesProvider.overrideWith((ref) async {
              todayFetches++;
              return const <Routine>[];
            }),
            pastRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
            myRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
          ],
          child: SyncTriggers(now: () => clock, child: const SizedBox.shrink()),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SyncTriggers)),
      );
      // 홈이 떠 있는 것처럼 구독한다 — 구독이 없으면 무효화해도 다시 받지 않는다.
      final sub = container.listen(todayRoutinesProvider, (_, _) {});
      addTearDown(sub.close);
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('자정을 넘겨 앱으로 돌아오면 목록을 다시 받는다', (tester) async {
      clock = DateTime(2026, 9, 30, 23, 50);
      await pumpWithClock(tester);
      expect(todayFetches, 1);

      clock = DateTime(2026, 10, 1, 0, 10);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(todayFetches, 2);
    });

    testWidgets('같은 날 돌아오면 다시 받지 않는다', (tester) async {
      clock = DateTime(2026, 9, 30, 9);
      await pumpWithClock(tester);

      clock = DateTime(2026, 9, 30, 21);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(todayFetches, 1);
    });

    testWidgets('앱을 내리지 않아도 자정이 지나면 다시 받는다', (tester) async {
      clock = DateTime(2026, 9, 30, 23, 59, 30);
      await pumpWithClock(tester);

      // 자정 타이머가 울릴 때 시계는 이미 다음 날이다.
      clock = DateTime(2026, 10, 1, 0, 0, 5);
      await tester.pump(const Duration(seconds: 40));
      await tester.pumpAndSettle();

      expect(todayFetches, 2);
    });
  });
}

class _CountingRepo extends StepProgressRepository {
  _CountingRepo({this.outcome = SyncOutcome.accepted}) : super(dio: Dio());

  SyncOutcome outcome;
  int calls = 0;

  @override
  Future<SyncOutcome> syncProgress({
    required String routineId,
    required Set<String> completedStepIds,
  }) async {
    calls++;
    return outcome;
  }
}
