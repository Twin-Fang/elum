import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/network/server_error.dart';
import 'package:elum/core/network/server_error_code.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/guardian/application/example_routine_seeder.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/features/guardian/data/routine_example_repository.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 홈 진입 시 예시 일과 생성 (#803)
class _FakeExampleRepository implements RoutineExampleRepository {
  _FakeExampleRepository(this.results);

  /// 부를 때마다 앞에서부터 하나씩 돌려준다
  final List<Attempt<List<Routine>>> results;
  final calls = <List<String>>[];

  @override
  Future<Attempt<List<Routine>>> createExamples(
    List<String> categoryCodes,
  ) async {
    calls.add(categoryCodes);
    return results.removeAt(0);
  }
}

const _offline = Attempt<List<Routine>>.failed(
  AppFailure(fault: NetworkFault.offline),
);

const _serverError = Attempt<List<Routine>>.failed(
  AppFailure(
    fault: NetworkFault.none,
    server: ServerError(code: ServerErrorCode.unknown, statusCode: 500),
  ),
);

void main() {
  late InMemoryStorage storage;
  late int todayFetchCount;

  ProviderContainer containerWith(_FakeExampleRepository repository) {
    todayFetchCount = 0;
    final container = ProviderContainer(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
        routineExampleRepositoryProvider.overrideWithValue(repository),
        todayRoutinesProvider.overrideWith((ref) async {
          todayFetchCount++;
          return const <Routine>[];
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() async {
    storage = InMemoryStorage();
    await storage.setSelectedProfileId('p1');
    await storage.setPendingExampleCategories(['MORNING_EVENING', 'OUTSIDE']);
    await storage.setPendingExampleProfileId('p1');
  });

  test('대기 분류가 없으면 요청하지 않는다 — 건너뛴 보호자에게 예시가 생기지 않게', () async {
    await storage.setPendingExampleCategories(const []);
    final repository = _FakeExampleRepository([]);
    final container = containerWith(repository);

    final outcome = await container
        .read(exampleRoutineSeederProvider)
        .seedPending();

    expect(outcome, ExampleSeedOutcome.nothingPending);
    expect(repository.calls, isEmpty);
  });

  test('성공하면 대기값을 비우고 오늘 목록을 다시 받는다 — 두 벌 요청·빈 홈 방지', () async {
    final repository = _FakeExampleRepository([
      const Attempt.ok(<Routine>[Routine(id: 'r1', title: '아침 준비')]),
    ]);
    final container = containerWith(repository);
    await container.read(todayRoutinesProvider.future);

    final outcome = await container
        .read(exampleRoutineSeederProvider)
        .seedPending();
    await container.read(todayRoutinesProvider.future);

    expect(outcome, ExampleSeedOutcome.created);
    expect(repository.calls.single, ['MORNING_EVENING', 'OUTSIDE']);
    expect(storage.pendingExampleCategories, isEmpty);
    expect(todayFetchCount, 2);
  });

  test('이미 만들어 빈 목록이 와도 성공이다', () async {
    final repository = _FakeExampleRepository([const Attempt.ok(<Routine>[])]);
    final container = containerWith(repository);

    final outcome = await container
        .read(exampleRoutineSeederProvider)
        .seedPending();

    expect(outcome, ExampleSeedOutcome.created);
    expect(storage.pendingExampleCategories, isEmpty);
  });

  test('오프라인은 횟수에 세지 않고 남긴다 — 오프라인으로 두 번 열어도 예시가 사라지지 않게', () async {
    final repository = _FakeExampleRepository([_offline, _offline]);
    final container = containerWith(repository);
    final seeder = container.read(exampleRoutineSeederProvider);

    await seeder.seedPending();
    final outcome = await seeder.seedPending();

    expect(outcome, ExampleSeedOutcome.failedWillRetry);
    expect(storage.pendingExampleCategories, ['MORNING_EVENING', 'OUTSIDE']);
    expect(storage.exampleSeedAttempts, 0);
  });

  test('서버 실패 한 번은 남겨 다음 홈 진입 때 다시 시도한다', () async {
    final repository = _FakeExampleRepository([_serverError]);
    final container = containerWith(repository);

    final outcome = await container
        .read(exampleRoutineSeederProvider)
        .seedPending();

    expect(outcome, ExampleSeedOutcome.failedWillRetry);
    expect(storage.exampleSeedAttempts, 1);
  });

  test('선택된 이룸이가 바뀌었으면 보내지 않고 버린다 — 합류한 남의 이룸이에게 예시가 들어가지 않게', () async {
    await storage.setSelectedProfileId('p2');
    final repository = _FakeExampleRepository([]);
    final container = containerWith(repository);

    final outcome = await container
        .read(exampleRoutineSeederProvider)
        .seedPending();

    expect(outcome, ExampleSeedOutcome.nothingPending);
    expect(repository.calls, isEmpty);
    expect(storage.pendingExampleCategories, isEmpty);
  });

  test('서버 실패 두 번째면 포기하고 비운다 — 홈을 열 때마다 실패 안내가 뜨지 않게', () async {
    final repository = _FakeExampleRepository([_serverError, _serverError]);
    final container = containerWith(repository);
    final seeder = container.read(exampleRoutineSeederProvider);

    await seeder.seedPending();
    final outcome = await seeder.seedPending();

    expect(outcome, ExampleSeedOutcome.failedGaveUp);
    expect(storage.pendingExampleCategories, isEmpty);
    expect(storage.exampleSeedAttempts, 0);
  });
  test('400 이면 재시도 없이 비운다 — 앱·서버 분류 코드가 어긋나 다시 해도 같다', () async {
    final repository = _FakeExampleRepository([
      const Attempt.failed(
        AppFailure(
          fault: NetworkFault.none,
          server: ServerError(code: ServerErrorCode.unknown, statusCode: 400),
        ),
      ),
    ]);
    final container = containerWith(repository);

    final outcome = await container
        .read(exampleRoutineSeederProvider)
        .seedPending();

    expect(outcome, ExampleSeedOutcome.failedGaveUp);
    expect(storage.pendingExampleCategories, isEmpty);
  });
}
