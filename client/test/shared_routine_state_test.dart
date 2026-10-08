import 'package:elum/features/child/application/child_routine_notifier.dart';
import 'package:elum/features/child/domain/routine_progress_record.dart';
import 'package:elum/features/child/presentation/child_home_screen.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/presentation/widgets/today_routine_section.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/features/guardian/application/routine_flow_state.dart';

// 완료 기록이 서버에 있어도 만들기 흐름의 옛 값이 가리면 보호자마다 진행률이 달라진다.
void main() {
  Routine routine(String id, {bool completed = false}) => Routine(
    id: id,
    title: id,
    status: completed ? 'COMPLETED' : 'CONFIRMED',
    steps: [
      ActionCard(
        id: '$id-step',
        description: '한 가지 행동',
        stepOrder: 1,
        completed: completed,
      ),
    ],
  );

  ProviderContainer containerFor(Routine current, List<Routine> fetched) {
    final container = ProviderContainer(
      overrides: [
        routineFlowProvider.overrideWith(() => _FlowWithRoutine(current)),
        todayRoutinesProvider.overrideWith((ref) async => fetched),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('두 보호자와 전환한 이룸이 홈은 생성자와 관계없이 서버의 완료 상태를 표시한다', () async {
    final server = [
      routine('a', completed: true),
      routine('b', completed: true),
    ];
    for (final creatorId in ['a', 'b']) {
      final container = containerFor(routine(creatorId), server);
      await container.read(todayRoutinesProvider.future);
      for (final list in [
        container.read(homeRoutinesProvider),
        container.read(childRoutinesProvider),
      ]) {
        expect(list.map((r) => r.id), ['a', 'b']);
        expect(list.length, 2);
        for (final r in list) {
          expect(r.status, 'COMPLETED');
          expect(routineProgress(r, const ChildRoutineState()), 1);
        }
      }
    }
  });

  test('서버에 아직 없는 새 일과는 양쪽 홈에서 바로 표시한다', () async {
    final current = routine('new');
    final fetched = [routine('existing')];
    final container = containerFor(current, fetched);
    await container.read(todayRoutinesProvider.future);

    expect(container.read(homeRoutinesProvider), [current, ...fetched]);
    expect(container.read(childRoutinesProvider), [current, ...fetched]);
  });

  test('최신 서버 목록을 표시해도 아직 못 보낸 오프라인 체크를 보존한다', () async {
    final server = routine('a', completed: true);
    final container = containerFor(routine('a'), [server]);
    await container.read(todayRoutinesProvider.future);
    // 서버는 완료지만 이 휴대폰에서 방금 해제했다. 전송 전에는 해제 상태를 보여야 한다.
    final pending = ChildRoutineState(
      progress: {'a': RoutineProgressRecord(completed: {})},
      pending: {'a'},
    );
    expect(
      routineProgress(container.read(homeRoutinesProvider).single, pending),
      0,
    );
    expect(
      routineProgress(container.read(childRoutinesProvider).single, pending),
      0,
    );
  });

  test('새 일과가 임시저장이라도 같은 id의 서버 승인 일과를 가리지 않는다', () async {
    final server = routine('a', completed: true);
    final container = containerFor(
      routine('a').copyWith(status: 'PENDING_REVIEW'),
      [server],
    );
    await container.read(todayRoutinesProvider.future);
    expect(container.read(homeRoutinesProvider), [server]);
    expect(container.read(childRoutinesProvider), [server]);
  });
}

class _FlowWithRoutine extends RoutineFlowNotifier {
  _FlowWithRoutine(this.routine);

  final Routine routine;

  @override
  RoutineFlowState build() => RoutineFlowState(routine: routine);
}
