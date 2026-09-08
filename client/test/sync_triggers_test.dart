import 'package:dio/dio.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/child/application/child_routine_notifier.dart';
import 'package:elum/features/child/application/sync_triggers.dart';
import 'package:elum/features/child/data/progress_store.dart';
import 'package:elum/features/child/data/step_progress_repository.dart';
import 'package:elum/features/child/domain/routine_progress_record.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
