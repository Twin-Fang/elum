import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_test/flutter_test.dart';

/// 시작한 일과는 지우지 않고(#533), 다 끝낸 일과는 고치지 않는다(#534).
/// 두 판단이 화면 버튼을 가르므로 서버 규칙과 같은 기준인지 고정한다.
void main() {
  ActionCard card(String id, {bool done = false}) => ActionCard(
    id: id,
    title: id,
    description: id,
    stepOrder: 1,
    completed: done,
  );

  Routine routine({
    String status = 'CONFIRMED',
    int completedStepCount = 0,
    List<ActionCard>? steps,
  }) => Routine(
    id: 'r1',
    status: status,
    completedStepCount: completedStepCount,
    steps: steps ?? [card('a'), card('b')],
  );

  group('hasStarted (#533)', () {
    test('한 단계도 하지 않았으면 시작 전이다 — 지울 수 있다', () {
      expect(routine().hasStarted, isFalse);
    });

    test('단계 하나를 했으면 시작했다', () {
      expect(
        routine(steps: [card('a', done: true), card('b')]).hasStarted,
        isTrue,
      );
    });

    test('단계 목록 없이 서버 집계만 와도 시작으로 본다', () {
      expect(routine(completedStepCount: 1).hasStarted, isTrue);
    });
  });

  group('isFinished (#534)', () {
    test('서버가 COMPLETED 로 주면 끝냈다', () {
      expect(routine(status: 'COMPLETED').isFinished, isTrue);
    });

    test('상태가 늦게 바뀌어도 단계를 다 했으면 끝냈다', () {
      expect(
        routine(
          steps: [card('a', done: true), card('b', done: true)],
        ).isFinished,
        isTrue,
      );
    });

    test('일부만 했으면 끝내지 않았다 — 아직 고칠 수 있다', () {
      expect(
        routine(steps: [card('a', done: true), card('b')]).isFinished,
        isFalse,
      );
    });
  });
}
