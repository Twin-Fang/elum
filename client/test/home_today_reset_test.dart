import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/presentation/widgets/today_routine_section.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';

/// 보호자 홈 `오늘 일과` 가 날짜가 바뀌면 초기화되고 승인 전 일과를 싣지 않는다 (이슈 #353).
///
/// 서버 `/today` 가 거른 목록을 받아도, 앱이 자정을 넘겨 켜져 있으면 받아 둔 값이
/// 어제 것이 된다. 홈이 한 번 더 거르지 않으면 다시 받기 전까지 어제 일과가 남는다.
void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 9);
  final yesterday = DateTime(now.year, now.month, now.day - 1, 9);

  Routine routine(String id, {String status = 'CONFIRMED', DateTime? at}) =>
      Routine(
        id: id,
        title: id,
        status: status,
        scheduledAt: at,
        steps: const [ActionCard(id: 'c', description: '카드', stepOrder: 1)],
      );

  Future<ProviderContainer> containerWith(List<Routine> fetched) async {
    final container = ProviderContainer(
      overrides: [todayRoutinesProvider.overrideWith((ref) async => fetched)],
    );
    addTearDown(container.dispose);
    await container.read(todayRoutinesProvider.future);
    return container;
  }

  test('받아 둔 목록에 어제 일과가 남아 있어도 홈에는 오늘 것만 뜬다', () async {
    final container = await containerWith([
      routine('어제 것', at: yesterday),
      routine('오늘 것', at: today),
    ]);

    expect(container.read(homeRoutinesProvider).map((r) => r.id), ['오늘 것']);
  });

  test('승인 전 일과는 어느 경로로 들어와도 홈에 뜨지 않는다', () async {
    final container = await containerWith([
      routine('임시저장', status: 'PENDING_REVIEW', at: today),
      routine('오늘 것', at: today),
    ]);

    expect(container.read(homeRoutinesProvider).map((r) => r.id), ['오늘 것']);
  });

  test('날짜를 모르는 일과는 서버가 거른 것으로 보고 그대로 둔다', () async {
    final container = await containerWith([routine('날짜 없음')]);

    expect(container.read(homeRoutinesProvider).map((r) => r.id), ['날짜 없음']);
  });

  test('흐름에 남은 어제 승인 일과는 오늘 일과 맨 앞에 붙지 않는다', () async {
    // 어제 승인한 일과가 흐름 상태에 남은 채 앱이 자정을 넘기면, 상태를 안 보고 붙인
    // 것이 앱을 다시 켜기 전까지 오늘 일과 맨 앞에 남는다.
    final container = await containerWith([routine('오늘 것', at: today)]);
    container
        .read(routineFlowProvider.notifier)
        .loadExisting(routine('어제 승인', at: yesterday));

    expect(container.read(homeRoutinesProvider).map((r) => r.id), ['오늘 것']);
  });

  test('방금 승인한 오늘 일과는 목록을 다시 받기 전에도 맨 앞에 뜬다', () async {
    final container = await containerWith([routine('오늘 것', at: today)]);
    container
        .read(routineFlowProvider.notifier)
        .loadExisting(routine('방금 승인', at: today));

    expect(container.read(homeRoutinesProvider).map((r) => r.id), [
      '방금 승인',
      '오늘 것',
    ]);
  });

  test('승인하면 오늘·지난·전체 목록을 모두 다시 받는다', () async {
    // 승인 경로가 목록을 다시 받지 않아, 승인한 일과가 오늘 일과와 지난 일과에 동시에
    // 떴다 (#353 재오픈). 지난 일과가 승인 전 목록을 그대로 들고 있던 것이 원인이다.
    final repo = _CountingRepo();
    final container = ProviderContainer(
      overrides: [routineRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    for (final p in [
      todayRoutinesProvider,
      pastRoutinesProvider,
      myRoutinesProvider,
    ]) {
      container.listen(p, (_, _) {});
    }
    await container.read(todayRoutinesProvider.future);
    await container.read(pastRoutinesProvider.future);
    await container.read(myRoutinesProvider.future);

    final flow = container.read(routineFlowProvider.notifier)
      ..loadExisting(routine('임시저장', status: 'PENDING_REVIEW'));
    expect(await flow.save(), isNull);
    await container.read(todayRoutinesProvider.future);
    await container.read(pastRoutinesProvider.future);
    await container.read(myRoutinesProvider.future);

    expect((repo.today, repo.past, repo.all), (2, 2, 2));
  });
}

class _CountingRepo implements RoutineRepository {
  int today = 0;
  int past = 0;
  int all = 0;

  @override
  Future<List<Routine>> getTodayRoutines() async {
    today++;
    return const [];
  }

  @override
  Future<List<Routine>> getPastRoutines() async {
    past++;
    return const [];
  }

  @override
  Future<List<Routine>> getMyRoutines() async {
    all++;
    return const [];
  }

  @override
  Future<Routine> confirm(Routine routine) async =>
      routine.copyWith(status: 'CONFIRMED');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
